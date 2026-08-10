import Foundation

enum EngineKind: String, Codable {
    case whisperKit
    case fluidAudio
}

enum LanguageSupport: String, Codable {
    case multilingual
    case englishOnly
    case european

    var label: String {
        switch self {
        case .multilingual: "100 языков"
        case .englishOnly: "только английский"
        case .european: "25 языков (вкл. русский)"
        }
    }
}

/// A model from the catalog (ModelCatalog.json). See docs/MODELS.md.
/// `Decodable` only: the catalog is read from the bundle and never written back.
struct ModelDescriptor: Decodable, Identifiable, Hashable {
    let id: String
    let engine: EngineKind
    let name: String
    let details: String
    let sizeMB: Int
    let languages: LanguageSupport
    let accuracy: Int // 1–10
    let speed: Int // 1–10
    let recommended: Bool
    let quantized: Bool
    /// Whether the model can translate speech to English (Whisper task=translate).
    /// Optional `translate` key in JSON; by default derived from the engine and
    /// languages. Turbo models need an explicit `false`: OpenAI fine-tuned them
    /// without translation data, so their translate mode doesn't work.
    let canTranslateToEnglish: Bool

    var sizeLabel: String {
        sizeMB >= 1000
            ? String(format: "%.1f GB", Double(sizeMB) / 1000)
            : "\(sizeMB) MB"
    }

    // recommended/quantized are optional in JSON — Swift's synthesized decoder
    // requires all keys, so we decode manually.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        engine = try container.decode(EngineKind.self, forKey: .engine)
        name = try container.decode(String.self, forKey: .name)
        details = try container.decode(String.self, forKey: .details)
        sizeMB = try container.decode(Int.self, forKey: .sizeMB)
        languages = try container.decode(LanguageSupport.self, forKey: .languages)
        accuracy = try container.decode(Int.self, forKey: .accuracy)
        speed = try container.decode(Int.self, forKey: .speed)
        recommended = try container.decodeIfPresent(Bool.self, forKey: .recommended) ?? false
        quantized = try container.decodeIfPresent(Bool.self, forKey: .quantized) ?? false
        // Parakeet (FluidAudio) always transcribes as is, and English-only models
        // have nothing to translate from — allow the rest unless JSON says otherwise.
        canTranslateToEnglish = try container.decodeIfPresent(Bool.self, forKey: .translate)
            ?? (engine == .whisperKit && languages != .englishOnly)
    }

    private enum CodingKeys: String, CodingKey {
        case id, engine, name, details, sizeMB, languages, accuracy, speed
        case recommended, quantized, translate
    }
}

import OSLog

enum ModelCatalog {
    static func load() -> [ModelDescriptor] {
        let log = Logger(category: "ModelCatalog")
        guard let url = Bundle.main.url(forResource: "ModelCatalog", withExtension: "json") else {
            log.error("ModelCatalog.json не найден в бандле")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let models = try JSONDecoder().decode([ModelDescriptor].self, from: data)
            log.info("Каталог загружен: \(models.count) моделей")
            return models
        } catch {
            log.error("Каталог не прочитан: \(error)")
            return []
        }
    }
}
