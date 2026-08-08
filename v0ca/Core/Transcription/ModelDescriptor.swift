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

/// Модель из каталога (ModelCatalog.json). См. docs/MODELS.md.
/// Только `Decodable`: каталог читается из бандла и обратно не пишется.
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
    /// Умеет ли модель переводить речь на английский (Whisper task=translate).
    /// В JSON — необязательный ключ `translate`; по умолчанию выводится из движка
    /// и языков. Явно `false` нужен турбо-моделям: OpenAI дообучала их без данных
    /// перевода, поэтому режим перевода у них не работает.
    let canTranslateToEnglish: Bool

    var sizeLabel: String {
        sizeMB >= 1000
            ? String(format: "%.1f GB", Double(sizeMB) / 1000)
            : "\(sizeMB) MB"
    }

    // recommended/quantized в JSON необязательны — synthesized-декодер Swift
    // требует все ключи, поэтому декодируем сами.
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
        // Parakeet (FluidAudio) всегда расшифровывает как есть, англоязычным
        // моделям переводить не с чего — остальным разрешаем, если JSON не спорит.
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
