import FluidAudio
import Foundation
import Observation
import OSLog
import WhisperKit

/// Владеет каталогом моделей и жизненным циклом активной модели:
/// скачивание с прогрессом, удаление, смена активной, загрузка в память и выгрузка.
@MainActor
@Observable
final class ModelManager {
    /// Состояние активной модели в памяти (для HUD и меню-бара).
    enum LoadState: Equatable {
        case idle
        case downloading(Int)
        case loading
        case ready
        case failed
    }

    /// Состояние модели на диске (для карточек каталога).
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
        // Если сохранённая активная модель больше не в каталоге (например, после
        // перехода на компактные варианты) — мигрируем на дефолтную.
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

    // MARK: - Диск

    /// Папка модели WhisperKit (та же, куда качает HFModelDownloader).
    static func modelFolder(for id: String) -> URL {
        HFModelDownloader.modelFolder(for: id)
    }

    func refreshDiskStates() {
        for model in catalog {
            if case .downloading = itemStates[model.id] { continue }
            itemStates[model.id] = isComplete(model) ? .downloaded : .notDownloaded
        }
    }

    /// Модель считается скачанной, только если на диске лежит не меньше ~80%
    /// ожидаемого размера. Иначе битые/недокачанные (прерванные) модели
    /// «притворялись» загруженными, хотя без файлов весов не работают.
    private func isComplete(_ model: ModelDescriptor) -> Bool {
        if model.engine == .fluidAudio {
            return FluidAudioEngine.modelsExist(for: Self.parakeetVersion(for: model.id))
        }
        let folder = Self.modelFolder(for: model.id)
        let expected = Int64(model.sizeMB) * 1_000_000
        guard expected > 0 else {
            // Нет ожидаемого размера — откат на старую проверку «папка непустая».
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

    // MARK: - Каталог: скачать / удалить / активировать

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
                // Отмена URLSession приходит как NSURLErrorCancelled — не считаем ошибкой.
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

    /// Отменить загрузку модели. Уже скачанные файлы остаются на диске — при
    /// повторном «Скачать» загрузка продолжится с недостающих.
    func cancelDownload(_ id: String) {
        downloadTasks[id]?.cancel()
        downloadTasks[id] = nil
        if case .downloading = itemStates[id] {
            itemStates[id] = .notDownloaded
        }
        log.info("Отмена загрузки \(id, privacy: .public)")
    }

    /// Удалить с диска. Если удаляем активную — выгружаем из памяти;
    /// при следующем использовании она скачается заново.
    func delete(_ id: String) {
        // Во время скачивания удалять нельзя — файлы пишутся прямо сейчас.
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

    /// Сменить активную: выгрузить старую, сразу прогреть новую.
    func setActive(_ id: String) {
        guard id != activeModelID, catalog.contains(where: { $0.id == id }) else { return }
        unload()
        activeModelID = id
        UserDefaults.standard.set(id, forKey: Prefs.Key.activeModelID)
        log.info("Активная модель: \(id, privacy: .public)")
        Task { await ensureLoaded() }
    }

    // MARK: - Жизненный цикл активной модели в памяти

    /// Загружает активную модель (скачивая при необходимости). Повторные вызовы безопасны.
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
            // Активная модель загрузилась — снимаем с неё статус «загрузка».
            // (refreshDiskStates пропускает записи в состоянии .downloading.)
            itemStates[id] = .downloaded
            refreshDiskStates()
        } catch {
            log.error("Загрузка модели не удалась: \(error)")
            loadState = .failed
        }
    }

    func transcribe(_ samples: [Float], options: TranscriptionOptions) async throws -> String {
        guard let engine, engine.isLoaded else { throw TranscriptionError.modelNotLoaded }
        // Настройка перевода могла остаться включённой с другой модели — гасим её,
        // если активная переводить не умеет (иначе Whisper .en выдаёт мусор).
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
            // Модели нет в каталоге — не падаем, откатываемся на дефолтную.
            return WhisperKitEngine(modelID: Self.defaultModelID)
        }
        switch model.engine {
        case .whisperKit:
            return WhisperKitEngine(modelID: model.id)
        case .fluidAudio:
            return FluidAudioEngine(version: Self.parakeetVersion(for: model.id))
        }
    }

    /// Parakeet-модели различаются версией: id с "v3" → v3 (25 языков), иначе v2 (EN).
    static func parakeetVersion(for id: String) -> AsrModelVersion {
        id.contains("v3") ? .v3 : .v2
    }
}
