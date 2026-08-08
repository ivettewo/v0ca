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
            // Уже грузится — ждём ту же задачу (ошибку/отмену не пробрасываем,
            // ниже перепроверим результат и при необходимости начнём заново).
            _ = try? await loadTask.value
            if whisper != nil { return }
        }
        let task = Task { [modelID, log] in
            log.info("Скачивание/проверка модели \(modelID, privacy: .public)")
            // Свой загрузчик вместо WhisperKit.download — тот качает побайтово и
            // потому крайне медленно. Файлы кладутся в ту же папку, что ждёт WhisperKit.
            let folder = try await HFModelDownloader.download(variant: modelID) { fraction in
                progress(fraction)
            }
            progress(1)
            log.info("Загрузка модели в память из \(folder.path, privacy: .public)")
            // prewarm: true — Core ML специализирует модель под чип на этапе загрузки,
            // иначе специализация откладывается до первого инференса (задержка при
            // первой диктовке). Стоит ~2x времени загрузки, но при старте это ок.
            let config = WhisperKitConfig(modelFolder: folder.path, prewarm: true)
            let instance = try await WhisperKit(config)
            // unload() во время загрузки: не «воскрешаем» модель устаревшей задачей.
            try Task.checkCancellation()
            // Прогрев: один прогон прогревает весь путь энкодер→декодер, чтобы первая
            // реальная транскрибация не платила за «холодный» инференс. Не тишина —
            // WhisperKit пропускает пустой звук, поэтому тихий тон 220 Гц (1 с).
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
        // Без явного языка Whisper префиллится английским токеном и переводит речь —
        // поэтому при "auto" обязательно включаем определение языка.
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
