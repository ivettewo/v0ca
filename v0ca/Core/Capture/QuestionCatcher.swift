import Foundation
import Observation
import OSLog

/// Finds the question in what the other side just said.
///
/// A rule can't do this. Looking for a question mark misses "расскажите про
/// опыт с…", which is a question in every way that matters, and catches
/// rhetorical ones, thinking aloud, and questions the speaker answers
/// themselves. So the last few lines go to a model, which is asked for one
/// judgement and nothing else.
///
/// **This sends the conversation out.** Not the whole call and not the audio,
/// but the other side's recent lines, continuously, while a meeting runs. The
/// panel says so, and the module page says so: that is the price of catching
/// questions, and it is not hidden anywhere.
///
/// Step 4 of docs/modules/MEETING-BUILD.md.
@MainActor
@Observable
final class QuestionCatcher {
    struct Caught: Equatable {
        let question: String
        /// The line it was heard in, so the panel knows which bubble to mark.
        let lineID: UUID
    }

    /// The current unanswered question, if any.
    private(set) var caught: Caught?

    @ObservationIgnored private let keys: ProviderKeyStore
    @ObservationIgnored private var isClassifying = false
    /// Already shown or already answered — asking twice about the same sentence
    /// is how a helper turns into a nag.
    @ObservationIgnored private var seen: Set<String> = []
    @ObservationIgnored private let log = Logger(category: "QuestionCatcher")

    /// How much of the conversation the classifier sees. Enough for "and what
    /// about you?" to make sense, little enough to stay cheap.
    private static let window = 8

    init(keys: ProviderKeyStore) {
        self.keys = keys
    }

    func reset() {
        caught = nil
        seen = []
    }

    func dismiss() {
        caught = nil
    }

    /// Marks a question as dealt with, so it never comes back.
    func markAnswered() {
        if let caught {
            seen.insert(caught.question.lowercased())
        }
        caught = nil
    }

    /// Called after every line from the other side. Own lines are never
    /// classified: answering your own question is nonsense, and sending your own
    /// speech out would double what leaves the Mac.
    func consider(lines: [MeetingLine]) async {
        guard !isClassifying, caught == nil else { return }
        guard let last = lines.last, last.side == .them else { return }
        guard let route = resolvedModel() else { return }

        isClassifying = true
        defer { isClassifying = false }

        let recent = lines.suffix(Self.window)
            .map { "\($0.side == .me ? "Я" : "Собеседник"): \($0.text)" }
            .joined(separator: "\n")

        do {
            let raw = try await ProviderClient.ask(
                route.provider, model: route.model, key: route.key,
                question: Self.prompt(recent)
            )
            guard let verdict = Self.parse(raw), verdict.confidence >= Prefs.meetingConfidence else {
                return
            }
            let key = verdict.question.lowercased()
            guard !seen.contains(key) else { return }
            seen.insert(key)
            caught = Caught(question: verdict.question, lineID: last.id)
        } catch {
            log.error("Классификатор не ответил: \(error)")
        }
    }

    // MARK: - The model's side of it

    private static func prompt(_ dialogue: String) -> String {
        """
        Идёт разговор. Ниже последние реплики; «Собеседник» — не вы.

        Определи, прозвучал ли в ПОСЛЕДНЕЙ реплике собеседника вопрос или \
        просьба, на которую нужно ответить сейчас. Игнорируй риторические \
        вопросы, размышления вслух, вопросы, на которые собеседник сам же \
        ответил, и светскую болтовню. Косвенная просьба вроде «расскажите про \
        опыт с…» — это вопрос.

        Реплики:
        \(dialogue)

        Ответь СТРОГО одним JSON-объектом без пояснений:
        {"is_question": true|false, "question": "чёткая формулировка вопроса", \
        "confidence": 0.0-1.0}
        Если вопроса нет — is_question=false, question="".
        """
    }

    private struct Verdict {
        let question: String
        let confidence: Double
    }

    /// Models wrap JSON in prose and fences however they like; take the braces.
    private static func parse(_ raw: String) -> Verdict? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            return nil
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["is_question"] as? Bool == true,
              let question = object["question"] as? String,
              !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        let confidence = (object["confidence"] as? Double)
            ?? (object["confidence"] as? Int).map(Double.init)
            ?? 0.5
        return Verdict(question: question, confidence: confidence)
    }

    /// The model picked for "Ask" answers here too: one place to choose, and it
    /// is already on the Providers tab.
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
