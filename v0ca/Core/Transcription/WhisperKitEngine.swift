import Foundation
import OSLog
import WhisperKit

final class WhisperKitEngine: TranscriptionEngine {
    private let modelID: String
    private let log = Logger(category: "WhisperKitEngine")
    private var whisper: WhisperKit?
    private var loadTask: Task<Void, Error>?

    init(modelID: String = "openai_whisper-small") {
        self.modelID = modelID
    }

    var isLoaded: Bool { whisper != nil }

    func load(progress: @escaping @Sendable (Double) -> Void) async throws {
        if whisper != nil { return }
        if let loadTask {
            // Already loading — await the same task (errors/cancellation are not
            // rethrown; we re-check the result below and restart if needed).
            _ = try? await loadTask.value
            if whisper != nil { return }
        }
        let task = Task { [modelID, log] in
            log.info("Скачивание/проверка модели \(modelID, privacy: .public)")
            // Our own downloader instead of WhisperKit.download — that one downloads
            // byte by byte and is thus extremely slow. Files go into the same folder WhisperKit expects.
            let folder = try await HFModelDownloader.download(variant: modelID) { fraction in
                progress(fraction)
            }
            progress(1)
            log.info("Загрузка модели в память из \(folder.path, privacy: .public)")
            // prewarm: true — Core ML specializes the model for the chip at load time,
            // otherwise specialization is deferred until the first inference (a delay
            // on the first dictation). Costs ~2x load time, but that's fine at startup.
            let config = WhisperKitConfig(modelFolder: folder.path, prewarm: true)
            let instance = try await WhisperKit(config)
            // unload() during loading: don't "resurrect" the model from a stale task.
            try Task.checkCancellation()
            // Warm-up: a single run warms the whole encoder→decoder path so the first
            // real transcription doesn't pay for a cold inference. Not silence —
            // WhisperKit skips empty audio, hence a quiet 220 Hz tone (1 s).
            log.info("Прогрев инференса…")
            var warmOptions = DecodingOptions()
            warmOptions.task = .transcribe
            warmOptions.language = "en"
            warmOptions.detectLanguage = false
            let warmSamples = (0..<16_000).map { i in
                0.05 * sinf(2 * .pi * 220 * Float(i) / 16_000)
            }
            _ = try? await instance.transcribe(
                audioArray: warmSamples,
                decodeOptions: warmOptions
            )
            try Task.checkCancellation()
            self.whisper = instance
            log.info("Модель готова")
        }
        loadTask = task
        defer { loadTask = nil }
        try await task.value
    }

    func unload() {
        loadTask?.cancel()
        loadTask = nil
        whisper = nil
    }

    func transcribe(_ samples: [Float], options opts: TranscriptionOptions) async throws -> String {
        guard let whisper else { throw TranscriptionError.modelNotLoaded }
        log.info("Транскрибация: \(samples.count) сэмплов (~\(samples.count / 16_000) с), язык: \(opts.language ?? "auto", privacy: .public), перевод: \(opts.translateToEnglish)")
        var options = DecodingOptions()
        options.task = opts.translateToEnglish ? .translate : .transcribe
        options.language = opts.language
        // Without an explicit language Whisper prefills the English token and translates
        // the speech — so with "auto" we must enable language detection.
        options.detectLanguage = (opts.language == nil)
        let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)
        let text = results
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        log.info("Готово: \(text.count) символов")
        return text
    }
}
