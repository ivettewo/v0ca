import FluidAudio
import Foundation
import Observation
import OSLog
import WhisperKit

/// Owns the model catalog and the active model's lifecycle:
/// download with progress, deletion, switching the active model, loading into memory and unloading.
@MainActor
@Observable
final class ModelManager {
    /// In-memory state of the active model (for the HUD and menu bar).
    enum LoadState: Equatable {
        case idle
        case downloading(Int)
        case loading
        case ready
        case failed
    }

    /// On-disk state of the model (for catalog cards).
    enum ItemState: Equatable {
        case notDownloaded
        case downloading(Int)
        case downloaded
    }

    static let defaultModelID = "openai_whisper-small_216MB"

    let catalog: [ModelDescriptor]
    private(set) var itemStates: [String: ItemState] = [:]
    private(set) var loadState: LoadState = .idle
    private(set) var activeModelID: String

    @ObservationIgnored private var engine: TranscriptionEngine?
    @ObservationIgnored private var downloadTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let log = Logger(category: "ModelManager")

    init() {
        catalog = ModelCatalog.load()
        // If the saved active model is no longer in the catalog (e.g. after
        // switching to compact variants) — migrate to the default one.
        let saved = UserDefaults.standard.string(forKey: Prefs.Key.activeModelID)
        if let saved, catalog.contains(where: { $0.id == saved }) {
            activeModelID = saved
        } else {
            activeModelID = Self.defaultModelID
            UserDefaults.standard.set(activeModelID, forKey: Prefs.Key.activeModelID)
        }
        refreshDiskStates()
    }

    var activeModel: ModelDescriptor? {
        catalog.first { $0.id == activeModelID }
    }

    // MARK: - Disk

    /// WhisperKit model folder (the same one HFModelDownloader downloads into).
    static func modelFolder(for id: String) -> URL {
        HFModelDownloader.modelFolder(for: id)
    }

    func refreshDiskStates() {
        for model in catalog {
            if case .downloading = itemStates[model.id] { continue }
            itemStates[model.id] = isComplete(model) ? .downloaded : .notDownloaded
        }
    }

    /// A model counts as downloaded only if at least ~80% of the expected size
    /// is on disk. Otherwise broken/partially downloaded (interrupted) models
    /// "pretended" to be installed even though they don't work without the weight files.
    private func isComplete(_ model: ModelDescriptor) -> Bool {
        if model.engine == .fluidAudio {
            return FluidAudioEngine.modelsExist(for: Self.parakeetVersion(for: model.id))
        }
        let folder = Self.modelFolder(for: model.id)
        let expected = Int64(model.sizeMB) * 1_000_000
        guard expected > 0 else {
            // No expected size — fall back to the old "folder is non-empty" check.
            return (try? FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty == false) ?? false
        }
        return folderSize(folder) >= Int64(Double(expected) * 0.8)
    }

    private func folderSize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // MARK: - Catalog: download / delete / activate

    func download(_ id: String) {
        guard itemStates[id] == .notDownloaded else { return }
        let isFluid = catalog.first { $0.id == id }?.engine == .fluidAudio
        itemStates[id] = .downloading(0)
        downloadTasks[id] = Task { [weak self] in
            do {
                let onProgress: @Sendable (Double) -> Void = { fraction in
                    let percent = Int(fraction * 100)
                    Task { @MainActor [weak self] in
                        if case .downloading = self?.itemStates[id] {
                            self?.itemStates[id] = .downloading(percent)
                        }
                    }
                }
                if isFluid {
                    _ = try await FluidAudioEngine.download(
                        version: Self.parakeetVersion(for: id), progress: onProgress
                    )
                } else {
                    _ = try await HFModelDownloader.download(variant: id, progress: onProgress)
                }
                guard !Task.isCancelled else { return }
                self?.itemStates[id] = .downloaded
                self?.log.info("Модель \(id, privacy: .public) скачана")
            } catch is CancellationError {
                self?.log.info("Скачивание \(id, privacy: .public) отменено")
            } catch {
                // URLSession cancellation arrives as NSURLErrorCancelled — not treated as an error.
                if (error as NSError).code == NSURLErrorCancelled {
                    self?.log.info("Скачивание \(id, privacy: .public) отменено")
                } else {
                    self?.itemStates[id] = .notDownloaded
                    self?.log.error("Скачивание \(id, privacy: .public) не удалось: \(error)")
                }
            }
            self?.downloadTasks[id] = nil
        }
    }

    /// Cancel the model download. Already-downloaded files stay on disk — hitting
    /// Download again resumes with the missing ones.
    func cancelDownload(_ id: String) {
        downloadTasks[id]?.cancel()
        downloadTasks[id] = nil
        if case .downloading = itemStates[id] {
            itemStates[id] = .notDownloaded
        }
        log.info("Отмена загрузки \(id, privacy: .public)")
    }

    /// Delete from disk. If deleting the active model — unload it from memory;
    /// it will be re-downloaded on next use.
    func delete(_ id: String) {
        // Can't delete while downloading — the files are being written right now.
        if case .downloading = itemStates[id] ?? .notDownloaded { return }
        if id == activeModelID {
            unload()
        }
        let folder = catalog.first { $0.id == id }?.engine == .fluidAudio
            ? FluidAudioEngine.cacheFolder(for: Self.parakeetVersion(for: id))
            : Self.modelFolder(for: id)
        try? FileManager.default.removeItem(at: folder)
        itemStates[id] = .notDownloaded
        log.info("Модель \(id, privacy: .public) удалена")
    }

    /// Switch the active model: unload the old one, warm up the new one right away.
    func setActive(_ id: String) {
        guard id != activeModelID, catalog.contains(where: { $0.id == id }) else { return }
        unload()
        activeModelID = id
        UserDefaults.standard.set(id, forKey: Prefs.Key.activeModelID)
        log.info("Активная модель: \(id, privacy: .public)")
        Task { await ensureLoaded() }
    }

    // MARK: - Active model in-memory lifecycle

    /// Loads the active model (downloading if needed). Repeated calls are safe.
    func ensureLoaded() async {
        if let engine, engine.isLoaded {
            loadState = .ready
            return
        }
        if engine == nil {
            engine = makeEngine(for: activeModelID)
        }
        guard let engine else {
            loadState = .failed
            return
        }
        if loadState == .idle || loadState == .failed {
            loadState = .downloading(0)
        }
        do {
            let id = activeModelID
            try await engine.load { [weak self] fraction in
                Task { @MainActor in
                    guard let self, self.loadState != .ready else { return }
                    self.loadState = fraction < 1 ? .downloading(Int(fraction * 100)) : .loading
                    if fraction < 1, case .notDownloaded = self.itemStates[id] ?? .notDownloaded {
                        self.itemStates[id] = .downloading(Int(fraction * 100))
                    }
                }
            }
            loadState = .ready
            // The active model has loaded — clear its "downloading" status.
            // (refreshDiskStates skips entries in the .downloading state.)
            itemStates[id] = .downloaded
            refreshDiskStates()
        } catch {
            log.error("Загрузка модели не удалась: \(error)")
            loadState = .failed
        }
    }

    func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> String {
        guard let engine, engine.isLoaded else { throw TranscriptionError.modelNotLoaded }
        // The translation setting may be left on from another model — turn it off
        // if the active one can't translate (otherwise Whisper .en produces garbage).
        var options = options
        if activeModel?.canTranslateToEnglish != true {
            options.translateToEnglish = false
        }
        return try await engine.transcribe(samples, options: options)
    }

    func unload() {
        engine?.unload()
        engine = nil
        loadState = .idle
    }

    private func makeEngine(for id: String) -> TranscriptionEngine? {
        guard let model = catalog.first(where: { $0.id == id }) else {
            // Model missing from the catalog — don't crash, fall back to the default one.
            return WhisperKitEngine(modelID: Self.defaultModelID)
        }
        switch model.engine {
        case .whisperKit:
            return WhisperKitEngine(modelID: model.id)
        case .fluidAudio:
            return FluidAudioEngine(version: Self.parakeetVersion(for: model.id))
        }
    }

    /// Parakeet models differ by version: id containing "v3" → v3 (25 languages), otherwise v2 (EN).
    static func parakeetVersion(for id: String) -> AsrModelVersion {
        id.contains("v3") ? .v3 : .v2
    }
}
