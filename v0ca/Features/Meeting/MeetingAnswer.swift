import Foundation
import Observation
import OSLog

/// The answer to a question caught in a call: one request, one result, shown in
/// a second window beside the panel.
///
/// Deliberately thin — the conversation is not a chat. Each question is asked on
/// its own, because the point is to answer what was just said, not to hold a
/// parallel dialogue while a meeting is happening.
@MainActor
@Observable
final class MeetingAnswer {
    enum Phase: Equatable {
        case idle
        case asking
        case answered
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var question = ""
    private(set) var text = ""

    var isVisible: Bool { phase != .idle }

    @ObservationIgnored private let keys: ProviderKeyStore
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(category: "MeetingAnswer")

    init(keys: ProviderKeyStore) {
        self.keys = keys
    }

    func dismiss() {
        task?.cancel()
        task = nil
        phase = .idle
        question = ""
        text = ""
    }

    func ask(_ question: String, context: [MeetingLine]) {
        task?.cancel()
        self.question = question
        text = ""
        phase = .asking

        task = Task { [weak self] in
            guard let self else { return }
            guard let route = resolvedModel() else {
                phase = .failed(L("Не выбрана модель — подключите провайдера в настройках"))
                return
            }
            do {
                let answer = try await ProviderClient.ask(
                    route.provider, model: route.model, key: route.key,
                    question: Self.prompt(question: question, context: context)
                )
                guard !Task.isCancelled else { return }
                text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                phase = .answered
            } catch {
                guard !Task.isCancelled else { return }
                log.error("Ответ не получен: \(error)")
                phase = .failed(Self.message(for: error))
            }
        }
    }

    /// The last few lines go with the question: "and how long did that take?"
    /// means nothing without what came before it.
    private static func prompt(question: String, context: [MeetingLine]) -> String {
        let recent = context.suffix(6)
            .map { "\($0.side == .me ? "Я" : "Собеседник"): \($0.text)" }
            .joined(separator: "\n")
        return """
        Идёт разговор. Последние реплики:
        \(recent)

        Собеседник спросил: \(question)

        Ответь коротко и по делу — это подсказка человеку прямо во время \
        разговора, а не статья. Без вступлений и без повторения вопроса.
        """
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

    private func resolvedModel() -> (provider: Provider, model: String, key: String)? {
        let value = UserDefaults.standard.string(forKey: Prefs.Key.askModel) ?? ""
        guard let slash = value.firstIndex(of: "/") else { return nil }
        let providerID = String(value[value.startIndex..<slash])
        let modelID = String(value[value.index(after: slash)...])
        guard let provider = ProviderCatalog.provider(id: providerID),
              let key = keys.keys[providerID], !modelID.isEmpty
        else { return nil }
        return (provider, modelID, key)
    }
}
