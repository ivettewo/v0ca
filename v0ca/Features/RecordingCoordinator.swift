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

    var modelState: ModelManager.LoadState { models.loadState }

    @ObservationIgnored var stateDidChange: ((State) -> Void)?
    /// Microphone permission denied — open settings on the Permissions tab.
    @ObservationIgnored var onMicDenied: (() -> Void)?

    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let fnMonitor = FnHotkeyMonitor()
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

    init(models: ModelManager, history: HistoryStore, stats: StatsStore) {
        self.models = models
        self.history = history
        self.stats = stats

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

        // Esc via CGEventTap: the Carbon hotkey above doesn't fire while fn/⌥ is
        // held in push-to-talk (the event arrives as "fn+Esc"). The tap catches
        // Esc with any modifiers; outside of recording the event is left alone.
        fnMonitor.onEscape = { [weak self] in
            guard let self, self.state == .recording || self.state == .processing else {
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
        if state == .recording {
            recorder.stop()
        }
        KeyboardShortcuts.disable(.cancelRecording)
        level = 0
        state = .hidden
    }

    private func start() {
        // Dictation is disabled until onboarding is finished: single entry point
        // for all triggers (hotkey, fn, push-to-talk, menu bar).
        guard Prefs.onboardingDone else { return }
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
                if !text.isEmpty {
                    history.add(samples: samples, text: text)
                    stats.addDictation(text: text)
                    if Prefs.appendSpace {
                        text += " "
                    }
                    TextInserter.insert(text)
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
