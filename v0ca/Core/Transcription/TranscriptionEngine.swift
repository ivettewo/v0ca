import Foundation

/// Common contract for transcription engines (WhisperKit, FluidAudio — stage 2).
/// See docs/ARCHITECTURE.md.
protocol TranscriptionEngine: AnyObject {
    var isLoaded: Bool { get }
    /// Loads the model into memory (downloading if needed). Called at app startup
    /// (the model is always hot) and again after unloading — in parallel with voice recording.
    /// `progress`: 0…1 — download progress; 1 — downloaded, loading into memory.
    func load(progress: @escaping @Sendable (Double) -> Void) async throws
    func unload()
    /// Audio: 16 kHz mono Float32.
    func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> String
}

struct TranscriptionOptions {
    /// ISO code ("ru", "en"…); nil — auto-detect.
    let language: String?
    /// Translate speech to English (Whisper task=translate).
    /// Turned off in `ModelManager` if the active model can't translate.
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

/// The "Recognition language" setting. Stored in UserDefaults: "auto" or an ISO code.
enum RecognitionLanguage {
    static var current: String? {
        let value = UserDefaults.standard.string(forKey: Prefs.Key.recognitionLanguage) ?? "auto"
        return value == "auto" ? nil : value
    }
}
