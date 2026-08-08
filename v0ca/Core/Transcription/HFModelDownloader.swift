import Foundation
import OSLog

/// Быстрая загрузка моделей WhisperKit напрямую с Hugging Face.
///
/// Штатный `WhisperKit.download` читает файл побайтово через `URLSession.bytes`
/// (`for try await byte in asyncBytes`) — это упирается в CPU и делает загрузку
/// многогигабайтных моделей чудовищно медленной независимо от скорости сети.
/// Здесь качаем нативным `URLSession.downloadTask` (чанковая загрузка) в ту же
/// папку, где WhisperKit потом ищет модель, поэтому его загрузчик не включается.
enum HFModelDownloader {
    static let repo = "argmaxinc/whisperkit-coreml"
    private static let log = Logger(category: "HFModelDownloader")

    enum DownloadError: Error { case listFailed(String), notFound(String), moveFailed }

    /// Корневая папка репозитория на диске (совпадает с тем, что использует WhisperKit).
    static var repoFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("huggingface/models/\(repo)", isDirectory: true)
    }

    static func modelFolder(for id: String) -> URL {
        repoFolder.appendingPathComponent(id, isDirectory: true)
    }

    private struct TreeItem: Decodable {
        let type: String
        let path: String
        let size: Int64?
        let lfs: LFS?
        struct LFS: Decodable { let size: Int64? }
        var byteSize: Int64 { lfs?.size ?? size ?? 0 }
    }

    /// Скачивает все файлы варианта модели. Возвращает папку модели.
    /// `progress` — доля 0…1 по суммарным байтам. Уже скачанные файлы (по размеру)
    /// пропускаются, так что вызов идемпотентен и поддерживает докачку.
    @discardableResult
    static func download(
        variant id: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let files = try await listFiles(variant: id)
        guard !files.isEmpty else { throw DownloadError.notFound(id) }

        let total = files.reduce(Int64(0)) { $0 + $1.byteSize }
        try FileManager.default.createDirectory(at: repoFolder, withIntermediateDirectories: true)

        // Разделяем на уже скачанные (по размеру) и требующие загрузки.
        var pending: [TreeItem] = []
        var alreadyDone: Int64 = 0
        for file in files {
            let localURL = repoFolder.appendingPathComponent(file.path)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path),
               (attrs[.size] as? Int64) == file.byteSize, file.byteSize > 0 {
                alreadyDone += file.byteSize
            } else {
                pending.append(file)
            }
        }

        let counter = ByteProgress(done: alreadyDone, total: total, report: progress)
        counter.emit()

        // Качаем параллельно (несколько файлов разом): прячет задержку HF-редиректа
        // на каждом файле и полнее использует канал. Ограничиваем одновременность.
        let maxConcurrent = 5
        try await withThrowingTaskGroup(of: Void.self) { group in
            var index = 0
            func addTask(_ file: TreeItem) {
                group.addTask {
                    try Task.checkCancellation()
                    let localURL = repoFolder.appendingPathComponent(file.path)
                    try FileManager.default.createDirectory(
                        at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true
                    )
                    guard let remote = resolveURL(for: file.path) else { return }
                    try await downloadFile(from: remote, to: localURL) { delta in
                        counter.add(delta)
                    }
                }
            }
            while index < pending.count && index < maxConcurrent {
                addTask(pending[index]); index += 1
            }
            while try await group.next() != nil {
                if index < pending.count { addTask(pending[index]); index += 1 }
            }
        }
        log.info("Модель \(id, privacy: .public) скачана (\(total) байт)")
        return modelFolder(for: id)
    }

    // MARK: - Список файлов

    private static func listFiles(variant id: String) async throws -> [TreeItem] {
        let listURL = URL(string:
            "https://huggingface.co/api/models/\(repo)/tree/main/\(id)?recursive=true")!
        let (data, response) = try await URLSession.shared.data(from: listURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DownloadError.listFailed(id)
        }
        let items = try JSONDecoder().decode([TreeItem].self, from: data)
        return items.filter { $0.type == "file" }
    }

    private static func resolveURL(for path: String) -> URL? {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: "https://huggingface.co/\(repo)/resolve/main/\(encoded)")
    }

    // MARK: - Один файл (нативная чанковая загрузка + прогресс)

    /// `onDelta` — сколько байт прибавилось с прошлого вызова (для суммарного прогресса).
    private static func downloadFile(
        from remote: URL,
        to local: URL,
        onDelta: @escaping @Sendable (Int64) -> Void
    ) async throws {
        final class State: @unchecked Sendable {
            var token: NSKeyValueObservation?
            var task: URLSessionDownloadTask?
            var last: Int64 = 0
        }
        let state = State()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let task = URLSession.shared.downloadTask(with: remote) { tempURL, _, error in
                    state.token?.invalidate()
                    if let error { cont.resume(throwing: error); return }
                    guard let tempURL else { cont.resume(throwing: DownloadError.moveFailed); return }
                    do {
                        try? FileManager.default.removeItem(at: local)
                        try FileManager.default.moveItem(at: tempURL, to: local)
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
                state.task = task
                state.token = task.progress.observe(\.completedUnitCount) { prog, _ in
                    let cur = prog.completedUnitCount
                    let delta = cur - state.last
                    state.last = cur
                    if delta > 0 { onDelta(delta) }
                }
                task.resume()
            }
        } onCancel: {
            // Реально прерываем сетевую загрузку, а не только наблюдение.
            state.token?.invalidate()
            state.task?.cancel()
        }
    }
}

/// Потокобезопасный счётчик суммарно скачанных байт для прогресса при
/// параллельной загрузке нескольких файлов.
private final class ByteProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var done: Int64
    private let total: Int64
    private let report: @Sendable (Double) -> Void

    init(done: Int64, total: Int64, report: @escaping @Sendable (Double) -> Void) {
        self.done = done
        self.total = total
        self.report = report
    }

    func add(_ delta: Int64) {
        lock.lock(); done += delta; let current = done; lock.unlock()
        report(total > 0 ? Double(current) / Double(total) : 0)
    }

    func emit() {
        lock.lock(); let current = done; lock.unlock()
        report(total > 0 ? Double(current) / Double(total) : 0)
    }
}
