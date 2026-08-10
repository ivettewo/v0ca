import Foundation
import Observation
import OSLog

/// Recording history: metadata in history.json, audio as WAV files next to it.
/// Size limit and age-based auto-delete come from settings.
@MainActor
@Observable
final class HistoryStore {
    private(set) var records: [HistoryRecord] = [] // newest first

    @ObservationIgnored private let log = Logger(category: "HistoryStore")

    static var baseFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("v0ca", isDirectory: true)
    }

    static var recordingsFolder: URL {
        baseFolder.appendingPathComponent("recordings", isDirectory: true)
    }

    private static var indexURL: URL {
        baseFolder.appendingPathComponent("history.json")
    }

    init() {
        try? FileManager.default.createDirectory(at: Self.recordingsFolder, withIntermediateDirectories: true)
        load()
        enforceLimits()
    }

    func audioURL(for record: HistoryRecord) -> URL {
        Self.recordingsFolder.appendingPathComponent(record.fileName)
    }

    // MARK: - Operations

    func add(samples: [Float], text: String) {
        let record = HistoryRecord(
            id: UUID(),
            date: Date(),
            duration: Double(samples.count) / Double(WavFile.sampleRate),
            text: text,
            favorite: false,
            fileName: UUID().uuidString + ".wav"
        )
        do {
            try WavFile.write(samples: samples, to: audioURL(for: record))
        } catch {
            log.error("Не удалось сохранить аудио: \(error)")
            return
        }
        records.insert(record, at: 0)
        enforceLimits()
        save()
    }

    func delete(_ id: UUID) {
        guard let record = records.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: audioURL(for: record))
        records.removeAll { $0.id == id }
        save()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].favorite.toggle()
        save()
    }

    func updateText(_ id: UUID, text: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].text = text
        save()
    }

    func samples(for record: HistoryRecord) throws -> [Float] {
        try WavFile.read(from: audioURL(for: record))
    }

    // MARK: - Limits

    /// Count limit + age-based auto-delete. Favorites are left alone.
    func enforceLimits() {
        var removed: [HistoryRecord] = []

        if let maxAge = Prefs.historyAutoDelete.maxAge {
            let cutoff = Date().addingTimeInterval(-maxAge)
            let expired = records.filter { !$0.favorite && $0.date < cutoff }
            removed.append(contentsOf: expired)
        }

        // Count limit: the minimum of "History size" and the auto-delete policy
        // (e.g. "Last 5"). Favorites are left alone.
        var limit = max(1, Prefs.historyLimit)
        if let policyCount = Prefs.historyAutoDelete.maxCount {
            limit = min(limit, policyCount)
        }
        let kept = records.filter { record in !removed.contains(where: { $0.id == record.id }) }
        if kept.count > limit {
            let overflow = kept.filter { !$0.favorite }.suffix(kept.count - limit)
            removed.append(contentsOf: overflow)
        }

        guard !removed.isEmpty else { return }
        for record in removed {
            try? FileManager.default.removeItem(at: audioURL(for: record))
        }
        records.removeAll { record in removed.contains(where: { $0.id == record.id }) }
        save()
        log.info("История: удалено \(removed.count) старых записей")
    }

    // MARK: - Disk

    private func load() {
        guard let data = try? Data(contentsOf: Self.indexURL) else { return }
        do {
            records = try JSONDecoder().decode([HistoryRecord].self, from: data)
        } catch {
            log.error("История не прочитана: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: Self.indexURL)
        } catch {
            log.error("История не сохранена: \(error)")
        }
    }
}
