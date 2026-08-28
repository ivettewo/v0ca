import AppKit
import Foundation
import Observation
import OSLog

/// The "Ask" flow: what happens after the words have been recognized locally.
/// Dictation inserts the text and is done; here the text becomes a question,
/// waits out a short countdown, goes to a provider and comes back as an answer.
@MainActor
@Observable
final class AskSession {
    enum Phase: Equatable {
        case idle
        /// The question is on screen and the countdown is running.
        case countdown
        /// The question is on its way to the provider.
        case asking
        case answered
        case failed(String)
    }

    private(set) var phase: Phase = .idle {
        didSet { onPhaseChange?() }
    }
    /// The panel has to resize with the bubble; nothing else observes this.
    @ObservationIgnored var onPhaseChange: (() -> Void)?
    private(set) var question = ""
    private(set) var answer = ""
    /// Seconds left before the question is sent; drives the bar and the label.
    private(set) var remaining: Double = 0
    /// The screenshot about to be sent, shown as a thumbnail in the bubble.
    /// Memory only — see `shot`.
    private(set) var preview: NSImage?
    /// The question is the user's own words, not our fallback prompt. The
    /// fallback is plumbing and has no business being read out on screen.
    private(set) var showsQuestion = true

    /// The screenshot bytes. Never written to disk: a full-screen capture is the
    /// most sensitive thing this app can produce, and the answer is text anyway.
    /// Dropped together with the bubble.
    @ObservationIgnored private var shot: Data?

    /// How long the user gets to cancel before the question leaves the Mac.
    static let countdownSeconds: Double = 5

    private let keys: ProviderKeyStore
    private let history: HistoryStore
    private let stats: StatsStore
    private let achievements: AchievementsStore

    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var request: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(category: "AskSession")

    init(
        keys: ProviderKeyStore,
        history: HistoryStore,
        stats: StatsStore,
        achievements: AchievementsStore
    ) {
        self.keys = keys
        self.history = history
        self.stats = stats
        self.achievements = achievements
    }

    var isActive: Bool { phase != .idle }

    /// Called with the locally recognized text once the recording ends.
    func begin(question text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cancelWork()
        question = trimmed
        showsQuestion = true
        answer = ""
        shot = nil
        preview = nil
        startCountdown()
    }

    private func startCountdown() {
        phase = .countdown
        remaining = Self.countdownSeconds
        // Counting down from a deadline rather than subtracting a fixed step:
        // Task.sleep guarantees "at least", so stepping drifts and five seconds
        // stretch into six.
        let deadline = Date().addingTimeInterval(Self.countdownSeconds)
        timer = Task { [weak self] in
            while !Task.isCancelled {
                let left = deadline.timeIntervalSinceNow
                guard let self else { return }
                self.remaining = max(0, left)
                guard left > 0 else { break }
                // The bar animates on its own; this only drives the seconds label.
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard let self, !Task.isCancelled, self.phase == .countdown else { return }
            self.send()
        }
    }

    /// The "Screen" mode: a picture plus whatever was said over it. The countdown
    /// is the chance to change your mind before the whole screen leaves the Mac.
    func begin(screenshot: Data, preview image: NSImage, question spoken: String = "") {
        cancelWork()
        let said = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        // Said nothing — fall back to a prompt that works for any screen.
        showsQuestion = !said.isEmpty
        if said.isEmpty {
            achievements.mark(.silentScreen)
        }
        question = said.isEmpty
            ? L(
                "Посмотри на снимок экрана. Если на нём есть вопрос или задача — ответь на неё. "
                + "Если нет — коротко объясни, что здесь происходит и на что стоит обратить внимание."
            )
            : said
        answer = ""
        shot = screenshot
        preview = image
        startCountdown()
    }

    /// Enter, or a click on the countdown bar — don't make the user wait.
    func sendNow() {
        guard phase == .countdown else { return }
        send()
    }

    func regenerate() {
        guard !question.isEmpty, phase != .asking else { return }
        achievements.mark(.regenerated)
        send()
    }

    /// Esc, the close button, or a click outside.
    func dismiss() {
        if phase == .countdown {
            achievements.mark(.askCancelled)
        }
        cancelWork()
        phase = .idle
        question = ""
        answer = ""
        // The screenshot lives exactly as long as the bubble does.
        shot = nil
        preview = nil
    }

    // MARK: - Request

    private func send() {
        // Regenerate can be pressed while an answer is still on its way; without
        // this the old task survives and overwrites the phase of the new one.
        cancelWork()
        guard let route = resolvedModel() else {
            phase = .failed(L("Не выбрана модель — подключите провайдера в настройках"))
            return
        }
        phase = .asking
        let startedAt = Date()
        request = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await ProviderClient.ask(
                    route.provider, model: route.model, key: route.key,
                    question: self.question, image: self.shot
                )
                guard !Task.isCancelled else { return }
                self.answer = text
                self.phase = .answered
                self.stats.addQuestion(
                    words: self.showsQuestion
                        ? self.question.split(whereSeparator: \.isWhitespace).count : 0,
                    withScreenshot: self.shot != nil
                )
                if let flag = AchievementsStore.flag(forProvider: route.provider.id) {
                    self.achievements.mark(flag)
                }
                if Date().timeIntervalSince(startedAt) > 30 {
                    self.achievements.mark(.patientAnswer)
                }
                // Closing the bubble used to lose the answer for good.
                self.history.addAnswer(
                    question: self.showsQuestion ? self.question : nil,
                    answer: text,
                    kind: self.shot == nil ? .ask : .screen
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.log.error("Вопрос не отправлен: \(error)")
                self.phase = .failed(Self.message(for: error))
            }
        }
    }

    /// "<provider>/<model>" from settings, plus the key from the Keychain.
    private func resolvedModel() -> (provider: Provider, model: String, key: String)? {
        // A screenshot needs the model picked for "Screen", which is filtered to
        // the ones that can actually see images.
        let key = shot == nil ? Prefs.Key.askModel : Prefs.Key.screenModel
        let value = UserDefaults.standard.string(forKey: key) ?? ""
        guard let slash = value.firstIndex(of: "/") else { return nil }
        let providerID = String(value[value.startIndex..<slash])
        let modelID = String(value[value.index(after: slash)...])
        guard let provider = ProviderCatalog.provider(id: providerID),
              let apiKey = keys.keys[providerID], !modelID.isEmpty else {
            return nil
        }
        return (provider, modelID, apiKey)
    }

    private static func message(for error: Error) -> String {
        switch error as? ProviderClient.Failure {
        case .rejected: L("Провайдер отклонил ключ")
        case .unreachable: L("Нет связи с провайдером")
        case .timedOut:
            L("Модель не ответила за %@ секунд", "\(Int(ProviderClient.answerTimeout))")
        case .http(let code): L("Провайдер ответил ошибкой %@", "\(code)")
        default: L("Непонятный ответ провайдера")
        }
    }

    private func cancelWork() {
        timer?.cancel()
        timer = nil
        request?.cancel()
        request = nil
    }
}
