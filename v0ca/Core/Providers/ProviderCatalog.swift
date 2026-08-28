import Foundation

/// An API provider for the modes that are not local: "Ask" and "Screen".
/// Speech recognition never goes through these — it always stays on device.
struct Provider: Identifiable, Hashable {
    /// How the key is passed and how the model list is shaped. Most providers
    /// copy OpenAI; Anthropic and Google each do their own thing.
    enum Flavor: Hashable {
        case openAI
        case anthropic
        case google
    }

    let id: String
    let name: String
    /// Shape of the key, shown as the field placeholder.
    let placeholder: String
    /// Endpoint that both validates the key and returns the model list.
    let modelsURL: String
    /// Where a question goes. `{model}` is substituted — only Google puts the
    /// model in the path.
    let chatURL: String
    let flavor: Flavor
}

/// A model as the provider itself reports it.
struct ProviderModel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    /// Whether the model accepts images. Only Anthropic reports this; elsewhere
    /// it stays nil and the "Screen" mode simply doesn't filter.
    let vision: Bool?
}

enum ProviderCatalog {
    static let all: [Provider] = [
        Provider(
            id: "openai", name: "OpenAI", placeholder: "sk-proj-…",
            modelsURL: "https://api.openai.com/v1/models",
            chatURL: "https://api.openai.com/v1/chat/completions", flavor: .openAI
        ),
        Provider(
            id: "anthropic", name: "Anthropic", placeholder: "sk-ant-…",
            modelsURL: "https://api.anthropic.com/v1/models?limit=1000",
            chatURL: "https://api.anthropic.com/v1/messages", flavor: .anthropic
        ),
        Provider(
            id: "xai", name: "xAI Grok", placeholder: "xai-…",
            modelsURL: "https://api.x.ai/v1/models",
            chatURL: "https://api.x.ai/v1/chat/completions", flavor: .openAI
        ),
        Provider(
            id: "google", name: "Google Gemini", placeholder: "AIza…",
            modelsURL: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000",
            chatURL: "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            flavor: .google
        ),
        Provider(
            // Model Studio endpoints are region-scoped; this is the US one.
            id: "qwen", name: "Alibaba Qwen", placeholder: "sk-…",
            modelsURL: "https://dashscope-us.aliyuncs.com/compatible-mode/v1/models",
            chatURL: "https://dashscope-us.aliyuncs.com/compatible-mode/v1/chat/completions",
            flavor: .openAI
        ),
    ]

    static func provider(id: String) -> Provider? {
        all.first { $0.id == id }
    }
}
