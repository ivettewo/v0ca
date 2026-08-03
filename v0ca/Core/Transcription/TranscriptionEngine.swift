import Foundation

/// Общий контракт движков транскрибации (WhisperKit, FluidAudio — этап 2).
/// См. docs/ARCHITECTURE.md.
protocol TranscriptionEngine: AnyObject {
    var isLoaded: Bool { get }
    /// Загружает модель в память (скачивая при необходимости). Вызывается при старте приложения
    /// (модель всегда горячая) и повторно после выгрузки — параллельно с записью голоса.
    /// `progress`: 0…1 — прогресс скачивания; 1 — скачано, идёт загрузка в память.
    func load(progress: @escaping @Sendable (Double) -> Void) async throws
    func unload()
    /// Аудио: 16 kHz mono Float32.
    func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> String
}

struct TranscriptionOptions {
    /// ISO-код ("ru", "en"…); nil — автоопределение.
    let language: String?
    /// Переводить речь на английский (Whisper task=translate).
    /// Гасится в `ModelManager`, если активная модель переводить не умеет.
    var translateToEnglish: Bool

    static var fromPrefs: TranscriptionOptions {
        TranscriptionOptions(
            language: RecognitionLanguage.current,
            translateToEnglish: Prefs.translateToEnglish
        )
    }
}

enum TranscriptionError: Error {
    case modelNotLoaded
}

/// Настройка «Язык распознавания». Хранится в UserDefaults: "auto" или ISO-код.
enum RecognitionLanguage {
    static let key = "recognitionLanguage"

    static var current: String? {
        let value = UserDefaults.standard.string(forKey: key) ?? "auto"
        return value == "auto" ? nil : value
    }
}
