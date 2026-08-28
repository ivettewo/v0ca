import Foundation
import OSLog

/// Talks to the providers' "list models" endpoints. One request does both jobs:
/// it proves the key works and it brings back the models to choose from.
///
/// This is the only place in the app besides the model downloader that goes to
/// the network, and it only ever contacts the provider whose key it carries.
enum ProviderClient {
    enum Failure: Error, Equatable {
        /// The provider answered, and the answer was "this key is no good".
        case rejected
        /// The provider answered with something else — quota, outage, wrong region.
        case http(Int)
        /// Never got an answer: offline, DNS, host down.
        case unreachable
        /// The provider took the request and went quiet for too long.
        case timedOut
        case malformed
    }

    private static let log = Logger(category: "ProviderClient")

    /// Seconds of silence from the provider before the question is given up on.
    static let answerTimeout: TimeInterval = 60

    static func listModels(_ provider: Provider, key: String) async throws -> [ProviderModel] {
        guard let url = URL(string: provider.modelsURL) else { throw Failure.malformed }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        switch provider.flavor {
        case .openAI:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .google:
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log.error("Провайдер \(provider.id) недоступен: \(error)")
            throw Self.failure(for: error)
        }
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }
        switch http.statusCode {
        case 200...299: break
        // Checked against the live endpoints with a deliberately wrong key:
        // OpenAI, Anthropic and Qwen answer 401, while xAI and Google answer 400
        // ("Incorrect API key" / "API key not valid"). This is a GET with no body,
        // so a 400 here can only be about the key.
        case 400, 401, 403: throw Failure.rejected
        default: throw Failure.http(http.statusCode)
        }

        let models = try parse(data, flavor: provider.flavor)
        // Providers list embeddings, speech and image models here too; none of
        // them can answer a question, so they must not reach the dropdown.
        return models.filter { isChatModel($0.id) }
    }

    /// "No answer" splits in two: nobody picked up, or nobody said anything.
    /// They need different words on screen.
    private static func failure(for error: Error) -> Failure {
        (error as? URLError)?.code == .timedOut ? .timedOut : .unreachable
    }

    // MARK: - Asking

    /// Sends one question and returns the answer as plain text. No history, no
    /// streaming: the "Ask" bubble shows a single answer at once.
    static func ask(
        _ provider: Provider, model: String, key: String, question: String,
        image: Data? = nil
    ) async throws -> String {
        let address = provider.chatURL.replacingOccurrences(
            of: "{model}",
            // A model id can contain characters that are fine in a path but not
            // guaranteed to be — Google puts it straight into the URL.
            with: model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        )
        guard let url = URL(string: address) else { throw Failure.malformed }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // A reasoning model can think for a while, but a minute of staring at a
        // skeleton is where waiting stops being waiting and starts being broken.
        request.timeoutInterval = Self.answerTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Every provider carries the picture differently, and all three want it
        // before the text — the models read the image first, then the question.
        let base64 = image?.base64EncodedString()
        let body: [String: Any]
        switch provider.flavor {
        case .openAI:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            var parts: [[String: Any]] = []
            if let base64 {
                parts.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64)"],
                ])
            }
            parts.append(["type": "text", "text": question])
            body = [
                "model": model,
                "messages": [["role": "user", "content": parts]],
            ]
        case .anthropic:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            var parts: [[String: Any]] = []
            if let base64 {
                parts.append([
                    "type": "image",
                    "source": [
                        "type": "base64", "media_type": "image/jpeg", "data": base64,
                    ],
                ])
            }
            parts.append(["type": "text", "text": question])
            // max_tokens is required by this API, unlike the others.
            body = [
                "model": model,
                "max_tokens": 2048,
                "messages": [["role": "user", "content": parts]],
            ]
        case .google:
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            var parts: [[String: Any]] = []
            if let base64 {
                parts.append(["inline_data": ["mime_type": "image/jpeg", "data": base64]])
            }
            parts.append(["text": question])
            body = ["contents": [["parts": parts]]]
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log.error("Запрос к \(provider.id) не прошёл: \(error)")
            throw Self.failure(for: error)
        }
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw Failure.rejected
            }
            throw Failure.http(http.statusCode)
        }
        guard let answer = answerText(data, flavor: provider.flavor), !answer.isEmpty else {
            throw Failure.malformed
        }
        return answer
    }

    private static func answerText(_ data: Data, flavor: Provider.Flavor) -> String? {
        let decoder = JSONDecoder()
        switch flavor {
        case .openAI:
            return try? decoder.decode(OpenAIAnswer.self, from: data)
                .choices.first?.message.content
        case .anthropic:
            return try? decoder.decode(AnthropicAnswer.self, from: data)
                .content.first(where: { $0.type == "text" })?.text
        case .google:
            return try? decoder.decode(GoogleAnswer.self, from: data)
                .candidates.first?.content.parts.compactMap(\.text).joined()
        }
    }

    private struct OpenAIAnswer: Decodable {
        struct Message: Decodable { let content: String? }
        struct Choice: Decodable { let message: Message }
        let choices: [Choice]
    }

    private struct AnthropicAnswer: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
    }

    private struct GoogleAnswer: Decodable {
        struct Part: Decodable { let text: String? }
        struct Content: Decodable { let parts: [Part] }
        struct Candidate: Decodable { let content: Content }
        let candidates: [Candidate]
    }

    // MARK: - Parsing

    private static func parse(_ data: Data, flavor: Provider.Flavor) throws -> [ProviderModel] {
        let decoder = JSONDecoder()
        switch flavor {
        case .openAI:
            guard let list = try? decoder.decode(OpenAIList.self, from: data) else {
                throw Failure.malformed
            }
            return list.data.map { ProviderModel(id: $0.id, name: $0.id, vision: nil) }
        case .anthropic:
            guard let list = try? decoder.decode(AnthropicList.self, from: data) else {
                throw Failure.malformed
            }
            return list.data.map {
                ProviderModel(
                    id: $0.id,
                    name: $0.display_name ?? $0.id,
                    vision: $0.capabilities?.image_input?.supported
                )
            }
        case .google:
            guard let list = try? decoder.decode(GoogleList.self, from: data) else {
                throw Failure.malformed
            }
            return list.models
                // Only models that can actually answer a prompt.
                .filter { $0.supportedGenerationMethods?.contains("generateContent") ?? true }
                .map {
                    // "models/gemini-3-pro" — the prefix is Google's resource path.
                    let id = $0.name.hasPrefix("models/") ? String($0.name.dropFirst(7)) : $0.name
                    return ProviderModel(id: id, name: $0.displayName ?? id, vision: nil)
                }
        }
    }

    /// Rejects the obviously non-conversational entries by name. A blunt filter,
    /// but the alternative is offering an embedding model as a chat model.
    private static func isChatModel(_ id: String) -> Bool {
        let lowered = id.lowercased()
        let banned = [
            "embed", "tts", "whisper", "audio", "moderation", "image", "dall-e",
            "transcribe", "realtime", "rerank", "veo", "imagen", "aqa", "sora",
        ]
        return !banned.contains { lowered.contains($0) }
    }

    // MARK: - Response shapes

    private struct OpenAIList: Decodable {
        struct Item: Decodable { let id: String }
        let data: [Item]
    }

    private struct AnthropicList: Decodable {
        struct Support: Decodable { let supported: Bool? }
        struct Capabilities: Decodable { let image_input: Support? }
        struct Item: Decodable {
            let id: String
            let display_name: String?
            let capabilities: Capabilities?
        }
        let data: [Item]
    }

    private struct GoogleList: Decodable {
        struct Item: Decodable {
            let name: String
            let displayName: String?
            let supportedGenerationMethods: [String]?
        }
        let models: [Item]
    }
}
