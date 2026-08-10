import Foundation
import KeyboardShortcuts
import Observation
import OSLog

/// Владеет всем циклом: хоткей → запись → транскрибация → вставка.
/// Стейт-машина HUD: hidden → recording → processing → done → hidden (см. docs/ARCHITECTURE.md).
/// Жизненный цикл моделей — в ModelManager.
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
    /// Разрешение на микрофон отклонено — открыть настройки на вкладке «Разрешения».
    @ObservationIgnored var onMicDenied: (() -> Void)?

    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let fnMonitor = FnHotkeyMonitor()
    @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
    @ObservationIgnored private var unloadTimer: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(category: "RecordingCoordinator")

    private var isPushToTalk: Bool {
        UserDefaults.standard.bool(forKey: Prefs.Key.pushToTalk)
    }

    /// Минуты бездействия до выгрузки модели; 0 — никогда. По умолчанию 15 (docs/MODELS.md).
    private var unloadAfterMinutes: Int {
        UserDefaults.standard.object(forKey: Prefs.Key.unloadModelAfterMinutes) as? Int ?? 15
    }

    init(models: ModelManager, history: HistoryStore, stats: StatsStore) {
        self.models = models
        self.history = history
        self.stats = stats

        // Push-to-talk: запись идёт, пока клавиша удерживается.
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

        // Esc через CGEventTap: Carbon-хоткей выше не срабатывает, пока в
        // push-to-talk зажата fn/⌥ (событие приходит как «fn+Esc»). Tap ловит
        // Esc с любыми модификаторами; вне записи событие не трогаем.
        fnMonitor.onEscape = { [weak self] in
            guard let self, self.state == .recording || self.state == .processing else {
                return false
            }
            self.cancel()
            return true
        }

        // Клавиша fn (Carbon её не умеет) — отдельный CGEventTap. Логика та же,
        // что у toggle-хоткея, но только когда пользователь назначил fn.
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

        // Предзагрузка при старте: к первому нажатию хоткея модель уже горячая
        // (docs/MODELS.md). До завершения онбординга не греем: ensureLoaded качает
        // активную модель, а пользователь ещё не выбрал её на шаге моделей.
        if Prefs.onboardingDone {
            Task { await models.ensureLoaded() }
        }
    }

    /// Повторная попытка поднять fn-монитор — на случай, если Accessibility
    /// выдали уже после запуска приложения. Идемпотентно.
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
        // Пока онбординг не завершён, диктовка выключена: единая точка входа
        // для всех триггеров (хоткей, fn, push-to-talk, меню-бар).
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
                // Если модель выгружена/не докачана — греем параллельно с записью.
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

    /// Перезапускает таймер бездействия. Вызывается после каждой транскрибации.
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
