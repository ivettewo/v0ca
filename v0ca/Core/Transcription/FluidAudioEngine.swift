import FluidAudio
import Foundation
import OSLog

/// Движок Parakeet TDT (FluidAudio) — быстрые CoreML-модели, ~600 МБ.
/// v2 — английский, v3 — 25 европейских языков (вкл. русский).
/// Модели качаются самим FluidAudio в `~/Library/Application Support/FluidAudio/Models`.
final class FluidAudioEngine: TranscriptionEngine {
    private let version: AsrModelVersion
    private let log = Logger(subsystem: "com.v0ca.app", category: "FluidAudioEngine")
    private var manager: AsrManager?
    private var loadTask: Task<Void, Error>?

    init(version: AsrModelVersion) {
        self.version = version
    }

    var isLoaded: Bool { manager != nil }

    func load(progress: @escaping @Sendable (Double) -> Void) async throws {
        if manager != nil { return }
        if let loadTask {
            _ = try? await loadTask.value
            if manager != nil { return }
        }
        let task = Task { [version, log] in
            log.info("Parakeet: скачивание/проверка (\(String(describing: version), privacy: .public))")
            let models = try await AsrModels.downloadAndLoad(version: version) { dl in
                progress(dl.fractionCompleted)
            }
            try Task.checkCancellation()
            progress(1)
            let manager = AsrManager()
            try await manager.loadModels(models)
            try Task.checkCancellation()
            self.manager = manager
            log.info("Parakeet готов")
        }
        loadTask = task
        defer { loadTask = nil }
        try await task.value
    }

    func unload() {
        loadTask?.cancel()
        loadTask = nil
        if let manager { Task { await manager.cleanup() } }
        manager = nil
    }

    func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> String {
        guard let manager else { throw TranscriptionError.modelNotLoaded }
        log.info("Parakeet транскрибация: \(samples.count) сэмплов (~\(samples.count / 16_000) с)")
        var state = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &state, language: nil)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Загрузка на диск (для ModelManager)

    /// Папка кэша моделей FluidAudio для версии.
    static func cacheFolder(for version: AsrModelVersion) -> URL {
        AsrModels.defaultCacheDirectory(for: version)
    }

    static func modelsExist(for version: AsrModelVersion) -> Bool {
        AsrModels.modelsExist(at: cacheFolder(for: version))
    }

    /// Скачать модели версии с прогрессом (без загрузки в память).
    @discardableResult
    static func download(
        version: AsrModelVersion,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try await AsrModels.download(version: version) { dl in
            progress(dl.fractionCompleted)
        }
    }
}
