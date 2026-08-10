import Foundation
import Observation
import OSLog

/// Статистика диктовки для вкладки «Диктовка»: агрегаты по дням в отдельном
/// JSON (`stats.json` рядом с историей). Не зависит от истории записей —
/// та подрезается лимитами, а статистика копится вечно (одна строка на день).
@MainActor
@Observable
final class StatsStore {
    struct DayStats: Codable {
        var words: Int
        var dictations: Int
    }

    /// Ключ — день в формате "yyyy-MM-dd" (локальная таймзона).
    private(set) var days: [String: DayStats] = [:]

    @ObservationIgnored private let log = Logger(category: "StatsStore")

    private static var fileURL: URL {
        HistoryStore.baseFolder.appendingPathComponent("stats.json")
    }

    init() {
        load()
    }

    /// Засчитать успешную диктовку: слова — по разбивке на пробелы.
    /// Перетранскрибация старых записей сюда не попадает — это не новая диктовка.
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

    // MARK: - Метрики

    var totalWords: Int {
        days.values.reduce(0) { $0 + $1.words }
    }

    /// Среднее по активным дням (дни хотя бы с одной диктовкой).
    var averageWordsPerDay: Int {
        guard !days.isEmpty else { return 0 }
        return totalWords / days.count
    }

    /// Дней подряд с диктовками. Сегодняшний день не обязателен, пока не кончился:
    /// если сегодня ещё не диктовали, стрик считается от вчера и не рвётся.
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

    // MARK: - Хранение

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
