import Foundation
import Observation
import OSLog

/// Dictation stats for the Dictation tab: per-day aggregates in a separate
/// JSON file (`stats.json` next to the history). Independent of the recording
/// history — that gets trimmed by limits, while stats accumulate forever
/// (one row per day).
@MainActor
@Observable
final class StatsStore {
    struct DayStats: Codable {
        var words: Int
        var dictations: Int
    }

    /// Keyed by day in "yyyy-MM-dd" format (local time zone).
    private(set) var days: [String: DayStats] = [:]

    @ObservationIgnored private let log = Logger(category: "StatsStore")

    private static var fileURL: URL {
        HistoryStore.baseFolder.appendingPathComponent("stats.json")
    }

    init() {
        load()
    }

    /// Count a successful dictation: words are split on whitespace.
    /// Re-transcribing old recordings doesn't go through here — it's not a new dictation.
    func addDictation(text: String) {
        let words = text.split(whereSeparator: \.isWhitespace).count
        guard words > 0 else { return }
        let key = Self.dayKey(Date())
        var day = days[key] ?? DayStats(words: 0, dictations: 0)
        day.words += words
        day.dictations += 1
        days[key] = day
        save()
    }

    // MARK: - Metrics

    var totalWords: Int {
        days.values.reduce(0) { $0 + $1.words }
    }

    /// Average over active days (days with at least one dictation).
    var averageWordsPerDay: Int {
        guard !days.isEmpty else { return 0 }
        return totalWords / days.count
    }

    /// Consecutive days with dictations. Today isn't required until it's over:
    /// if nothing was dictated yet today, the streak counts from yesterday and doesn't break.
    var streakDays: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if days[Self.dayKey(day)] == nil {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        while days[Self.dayKey(day)] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - Storage

    private static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        do {
            days = try JSONDecoder().decode([String: DayStats].self, from: data)
        } catch {
            log.error("Статистика не прочитана: \(error)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: HistoryStore.baseFolder, withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(days)
            try data.write(to: Self.fileURL)
        } catch {
            log.error("Статистика не записана: \(error)")
        }
    }
}
