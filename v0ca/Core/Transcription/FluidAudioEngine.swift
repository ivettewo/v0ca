import FluidAudio
import Foundation
import OSLog

/// Parakeet TDT engine (FluidAudio) — fast CoreML models, ~600 MB.
/// v2 — English, v3 — 25 European languages (incl. Russian).
/// FluidAudio itself downloads the models into `~/Library/Application Support/FluidAudio/Models`.
final class FluidAudioEngine: TranscriptionEngine {
    private let version: AsrModelVersion
    private let log = Logger(category: "FluidAudioEngine")
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

    // MARK: - Downloading to disk (for ModelManager)

    /// FluidAudio model cache folder for the version.
    static func cacheFolder(for version: AsrModelVersion) -> URL {
        AsrModels.defaultCacheDirectory(for: version)
    }

    static func modelsExist(for version: AsrModelVersion) -> Bool {
        AsrModels.modelsExist(at: cacheFolder(for: version))
    }

    /// Download the version's models with progress (without loading into memory).
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
