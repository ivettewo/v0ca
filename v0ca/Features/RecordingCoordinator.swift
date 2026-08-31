import AppKit
import Foundation
import KeyboardShortcuts
import Observation
import OSLog

/// Owns the whole cycle: hotkey → recording → transcription → insertion.
/// HUD state machine: hidden → recording → processing → done → hidden (see docs/ARCHITECTURE.md).
/// Model lifecycle lives in ModelManager.
@MainActor
@Observable
final class RecordingCoordinator {
    enum State: Equatable {
        case hidden
        case recording
        case processing
        case done
    }


    private(set) var state: State = .hidden {
        didSet { stateDidChange?(state) }
    }
    private(set) var level: Float = 0

    let models: ModelManager
    let history: HistoryStore
    let stats: StatsStore
    let achievements: AchievementsStore
    /// API keys for the non-local modes. Held here so the settings window can
    /// reach the same instance the rest of the app uses.
    let providerKeys = ProviderKeyStore()
    /// The "Ask" flow. Only used when that mode is selected in the bar.
    let ask: AskSession

    var modelState: ModelManager.LoadState { models.loadState }

    @ObservationIgnored var stateDidChange: ((State) -> Void)?
    /// Microphone permission denied — open settings on the Permissions tab.
    @ObservationIgnored var onMicDenied: (() -> Void)?
    /// Screen Recording permission missing — same tab.
    @ObservationIgnored var onScreenDenied: (() -> Void)?

    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let fnMonitor = FnHotkeyMonitor()
    /// The screenshot taken at the start of a "Screen" recording. Memory only,
    /// handed to the bubble when the words are ready and dropped right after.
    @ObservationIgnored private var pendingShot: (jpeg: Data, preview: NSImage)?
    @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
    @ObservationIgnored private var unloadTimer: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(category: "RecordingCoordinator")

    private var isPushToTalk: Bool {
        UserDefaults.standard.bool(forKey: Prefs.Key.pushToTalk)
    }

    /// Idle minutes before the model is unloaded; 0 — never. Defaults to 15 (docs/MODELS.md).
    private var unloadAfterMinutes: Int {
        UserDefaults.standard.object(forKey: Prefs.Key.unloadModelAfterMinutes) as? Int ?? 15
    }

    init(
        models: ModelManager,
        history: HistoryStore,
        stats: StatsStore,
        achievements: AchievementsStore
    ) {
        self.models = models
        self.history = history
        self.stats = stats
        self.achievements = achievements
        ask = AskSession(
            keys: providerKeys, history: history,
            stats: stats, achievements: achievements
        )

        // Push-to-talk: recording lasts while the key is held down.
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            guard let self, self.isPushToTalk else { return }
            if self.state == .hidden || self.state == .done {
                self.start()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            guard let self else { return }
            if self.isPushToTalk {
                if self.state == .recording {
                    self.finish()
                }
            } else {
                self.toggle()
            }
        }
        KeyboardShortcuts.onKeyUp(for: .cancelRecording) { [weak self] in
            self?.cancel()
        }
        KeyboardShortcuts.disable(.cancelRecording)

        // Mode switching from anywhere. Only meaningful while the bar is on —
        // the mode has no effect otherwise, and silently eating ⌘⇧1 would be rude.
        for mode in Prefs.HUDMode.allCases {
            KeyboardShortcuts.onKeyUp(for: .mode(mode)) {
                guard Prefs.hudAlwaysVisible else { return }
                UserDefaults.standard.set(mode.rawValue, forKey: Prefs.Key.hudMode)
            }
        }

        // Esc via CGEventTap: the Carbon hotkey above doesn't fire while fn/⌥ is
        // held in push-to-talk (the event arrives as "fn+Esc"). The tap catches
        // Esc with any modifiers; outside of recording the event is left alone.
        fnMonitor.onEscape = { [weak self] in
            guard let self else { return false }
            // The Ask bubble outlives the recording, and Esc has to close it too.
            if self.ask.isActive {
                self.ask.dismiss()
                return true
            }
            guard self.state == .recording || self.state == .processing else {
                return false
            }
            self.cancel()
            return true
        }

        // The fn key (Carbon can't handle it) — a separate CGEventTap. Same logic
        // as the toggle hotkey, but only when the user has assigned fn.
        fnMonitor.onFnDown = { [weak self] in
            guard let self, Prefs.toggleRecordingUsesFn, self.isPushToTalk else { return }
            if self.state == .hidden || self.state == .done {
                self.start()
            }
        }
        fnMonitor.onFnUp = { [weak self] in
            guard let self, Prefs.toggleRecordingUsesFn else { return }
            if self.isPushToTalk {
                if self.state == .recording {
                    self.finish()
                }
            } else {
                self.toggle()
            }
        }
        fnMonitor.start()

        // Preload on startup: the model is already warm by the first hotkey press
        // (docs/MODELS.md). Don't warm up before onboarding is finished: ensureLoaded
        // downloads the active model, and the user hasn't picked one on the models step yet.
        if Prefs.onboardingDone {
            Task { await models.ensureLoaded() }
        }
    }

    /// Retry starting the fn monitor — in case Accessibility was granted
    /// after the app launched. Idempotent.
    func startFnMonitorIfNeeded() {
        fnMonitor.start()
    }

    func toggle() {
        switch state {
        case .hidden, .done:
            start()
        case .recording:
            finish()
        case .processing:
            break
        }
    }

    func cancel() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        pendingShot = nil
        if state == .recording {
            recorder.stop()
        }
        KeyboardShortcuts.disable(.cancelRecording)
        level = 0
        state = .hidden
    }

    private var isScreenMode: Bool {
        Prefs.hudAlwaysVisible && Prefs.hudMode == .screen
    }

    /// Grabs the display and keeps it in memory until the recording ends.
    private func captureScreen() {
        guard ScreenCapture.hasPermission else {
            ScreenCapture.requestPermission()
            onScreenDenied?()
            return
        }
        pendingShot = nil
        Task {
            do {
                let shot = try await ScreenCapture.captureDisplayUnderCursor()
                pendingShot = (shot.jpeg, shot.preview)
                if shot.optimized {
                    achievements.mark(.optimizedShot)
                }
            } catch {
                log.error("Снимок не сделан: \(error)")
            }
        }
    }

    private func start() {
        // Dictation is disabled until onboarding is finished: single entry point
        // for all triggers (hotkey, fn, push-to-talk, menu bar).
        guard Prefs.onboardingDone else { return }
        // In "Screen" the shot is grabbed the moment the key goes down — before
        // the bar has a chance to change and before the user starts moving
        // windows around — and the voice on top of it becomes the question.
        if isScreenMode {
            captureScreen()
        }
        Task {
            guard await AudioRecorder.requestMicAccess() == .granted else {
                log.error("Нет разрешения на микрофон — открываю настройки")
                onMicDenied?()
                return
            }
            do {
                recorder.onLevel = { [weak self] value in
                    self?.level = value
                }
                try recorder.start()
                SoundFeedback.recordStart()
                state = .recording
                unloadTimer?.cancel()
                KeyboardShortcuts.enable(.cancelRecording)
                // If the model is unloaded/not fully downloaded — warm it up in parallel with recording.
                Task { await models.ensureLoaded() }
            } catch {
                log.error("Не удалось начать запись: \(error)")
                state = .hidden
            }
        }
    }

    private func finish() {
        let samples = recorder.stop()
        level = 0
        state = .processing
        transcriptionTask = Task {
            defer {
                KeyboardShortcuts.disable(.cancelRecording)
                scheduleUnload()
            }
            await models.ensureLoaded()
            guard models.loadState == .ready, !Task.isCancelled else {
                if !Task.isCancelled { state = .hidden }
                return
            }
            do {
                var text = try await models.transcribe(samples, options: .fromPrefs)
                guard !Task.isCancelled else { return }

                // A screenshot is worth sending even in silence: without words the
                // bubble falls back to its own prompt.
                if let shot = pendingShot {
                    pendingShot = nil
                    // No dictation row here: the question lands in the history as
                    // part of the answer, and logging it twice reads as a bug.
                    if !text.isEmpty {
                        stats.addDictation(
                            text: text,
                            seconds: Double(samples.count) / Double(WavFile.sampleRate)
                        )
                    }
                    ask.begin(screenshot: shot.jpeg, preview: shot.preview, question: text)
                    SoundFeedback.recordDone()
                    state = .hidden
                    return
                }

                if !text.isEmpty {
                    let asking = Prefs.hudMode == .ask && Prefs.hudAlwaysVisible
                    if !asking {
                        history.add(samples: samples, text: text)
                    }
                    stats.addDictation(
                        text: text,
                        seconds: Double(samples.count) / Double(WavFile.sampleRate)
                    )
                    if let engine = models.activeModel?.engine {
                        achievements.mark(engine: engine)
                    }
                    // In "Ask" the words are a question, not something to paste:
                    // they go to the bubble instead of the active app.
                    if asking {
                        ask.begin(question: text)
                        // The green checkmark means "pasted into your app", and in
                        // this mode nothing was pasted — the bubble is the result.
                        SoundFeedback.recordDone()
                        state = .hidden
                        return
                    } else {
                        if Prefs.appendSpace {
                            text += " "
                        }
                        TextInserter.insert(text)
                    }
                }
                SoundFeedback.recordDone()
                state = .done
                try? await Task.sleep(for: .seconds(1.4))
                guard state == .done else { return }
                state = .hidden
            } catch {
                log.error("Транскрибация не удалась: \(error)")
                if !Task.isCancelled {
                    state = .hidden
                }
            }
        }
    }

    /// Restarts the idle timer. Called after every transcription.
    private func scheduleUnload() {
        unloadTimer?.cancel()
        let minutes = unloadAfterMinutes
        guard minutes > 0 else { return }
        unloadTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled, let self, self.state == .hidden else { return }
            self.models.unload()
            self.log.info("Модель выгружена после \(minutes) мин бездействия")
        }
    }
}
