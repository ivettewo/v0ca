import Foundation
import Observation
import OSLog

/// Dictation stats for the Dictation and Stats tabs: per-day aggregates in a separate
/// JSON file (`stats.json` next to the history). Independent of the recording
/// history — that gets trimmed by limits, while stats accumulate forever
/// (one row per day).
@MainActor
@Observable
final class StatsStore {
    struct DayStats: Codable {
        var words: Int
        var dictations: Int
        /// Characters of the recognized text — the basis for "time saved":
        /// typing speed in characters doesn't depend on the language, unlike
        /// words per minute (Russian words are longer than English ones).
        var chars: Int
        /// Total speech duration for the day, in seconds.
        var seconds: Double
        /// Dictations by hour of the day; the key is the hour, "0"…"23".
        /// Int keys would encode as a flat array — hence strings.
        var hours: [String: Int]
        /// The longest single dictation of the day, in words.
        var maxWords: Int
        /// The best pace of a single dictation, words per minute.
        var maxWordsPerMinute: Double
        /// Questions sent to a model: by voice, and with a screenshot attached.
        var asks: Int
        var screens: Int
        /// The longest question of the day, in words. Separate from `maxWords`,
        /// which counts dictations — a long transcript isn't a long question.
        var maxAskWords: Int
        /// Dictations by length, keyed by bucket ("0-15", "300+"). Written only
        /// while the "Расширенная статистика" module is on — see docs/STATS.md.
        var durations: [String: Int]
        /// The longest single dictation of the day, in seconds. Same module.
        var maxSeconds: Double

        init(
            words: Int = 0,
            dictations: Int = 0,
            chars: Int = 0,
            seconds: Double = 0,
            hours: [String: Int] = [:],
            maxWords: Int = 0,
            maxWordsPerMinute: Double = 0,
            asks: Int = 0,
            screens: Int = 0,
            maxAskWords: Int = 0,
            durations: [String: Int] = [:],
            maxSeconds: Double = 0
        ) {
            self.words = words
            self.dictations = dictations
            self.chars = chars
            self.seconds = seconds
            self.hours = hours
            self.maxWords = maxWords
            self.maxWordsPerMinute = maxWordsPerMinute
            self.asks = asks
            self.screens = screens
            self.maxAskWords = maxAskWords
            self.durations = durations
            self.maxSeconds = maxSeconds
        }

        /// Everything below `dictations` was added later. Synthesized decoding
        /// does not fall back to default values for missing keys — it throws
        /// `keyNotFound`, which would wipe every stat accumulated so far.
        /// Days written by older versions keep zeros: we don't backfill estimates.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            words = try container.decode(Int.self, forKey: .words)
            dictations = try container.decode(Int.self, forKey: .dictations)
            chars = try container.decodeIfPresent(Int.self, forKey: .chars) ?? 0
            seconds = try container.decodeIfPresent(Double.self, forKey: .seconds) ?? 0
            hours = try container.decodeIfPresent([String: Int].self, forKey: .hours) ?? [:]
            maxWords = try container.decodeIfPresent(Int.self, forKey: .maxWords) ?? 0
            maxWordsPerMinute =
                try container.decodeIfPresent(Double.self, forKey: .maxWordsPerMinute) ?? 0
            asks = try container.decodeIfPresent(Int.self, forKey: .asks) ?? 0
            screens = try container.decodeIfPresent(Int.self, forKey: .screens) ?? 0
            maxAskWords = try container.decodeIfPresent(Int.self, forKey: .maxAskWords) ?? 0
            durations = try container.decodeIfPresent([String: Int].self, forKey: .durations) ?? [:]
            maxSeconds = try container.decodeIfPresent(Double.self, forKey: .maxSeconds) ?? 0
        }
    }

    /// Keyed by day in "yyyy-MM-dd" format (local time zone).
    private(set) var days: [String: DayStats] = [:]

    @ObservationIgnored private let log = Logger(category: "StatsStore")

    /// Typing speed the "time saved" estimate is measured against, in characters
    /// per minute — roughly an average typist.
    static let typingCharsPerMinute: Double = 200

    /// A dictation shorter than this doesn't count towards the pace record:
    /// three words blurted out in a second would give an absurd words-per-minute.
    private static let paceMinWords = 10
    private static let paceMinSeconds: Double = 5

    private static var fileURL: URL {
        HistoryStore.baseFolder.appendingPathComponent("stats.json")
    }

    init() {
        load()
    }

    /// Count a successful dictation: words are split on whitespace.
    /// Re-transcribing old recordings doesn't go through here — it's not a new dictation.
    func addDictation(text: String, seconds: Double) {
        let words = text.split(whereSeparator: \.isWhitespace).count
        guard words > 0 else { return }
        let now = Date()
        let key = Self.dayKey(now)
        var day = days[key] ?? DayStats()
        day.words += words
        day.dictations += 1
        day.chars += text.count
        day.seconds += seconds
        let hour = String(Calendar.current.component(.hour, from: now))
        day.hours[hour, default: 0] += 1
        day.maxWords = max(day.maxWords, words)
        // Length breakdown belongs to the module: switched off, it records
        // nothing at all rather than quietly filling a hidden chart.
        if ModuleCatalog.isEnabled("stats") {
            day.durations[Self.bucket(seconds), default: 0] += 1
            day.maxSeconds = max(day.maxSeconds, seconds)
        }
        if words >= Self.paceMinWords, seconds >= Self.paceMinSeconds {
            day.maxWordsPerMinute = max(day.maxWordsPerMinute, Double(words) / seconds * 60)
        }
        days[key] = day
        save()
    }

    /// A question that reached a model. Counted apart from dictations: the words
    /// were spoken (so they are already in the dictation totals), but the request
    /// itself is what these numbers are about.
    func addQuestion(words: Int, withScreenshot: Bool) {
        let key = Self.dayKey(Date())
        var day = days[key] ?? DayStats()
        if withScreenshot {
            day.screens += 1
        } else {
            day.asks += 1
        }
        day.maxAskWords = max(day.maxAskWords, words)
        days[key] = day
        save()
    }

    // MARK: - Totals

    var totalWords: Int {
        days.values.reduce(0) { $0 + $1.words }
    }

    var totalChars: Int {
        days.values.reduce(0) { $0 + $1.chars }
    }

    var totalDictations: Int {
        days.values.reduce(0) { $0 + $1.dictations }
    }

    var totalSeconds: Double {
        days.values.reduce(0) { $0 + $1.seconds }
    }

    /// Average over active days (days with at least one dictation).
    var averageWordsPerDay: Int {
        guard !days.isEmpty else { return 0 }
        return totalWords / days.count
    }

    /// How much longer typing the same text would have taken, in seconds.
    /// Only days recorded after character counting was added contribute.
    var savedSeconds: Double {
        max(0, Double(totalChars) / Self.typingCharsPerMinute * 60 - totalSeconds)
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

    // MARK: - Length

    /// Buckets from the "Настройки · Статистика" mockup, in display order. The
    /// last one is open-ended.
    static let durationBuckets: [(key: String, upTo: Double, label: String)] = [
        ("0-5", 5, "до 5 с"),
        ("5-15", 15, "5–15 с"),
        ("15-30", 30, "15–30 с"),
        ("30-60", 60, "30–60 с"),
        ("60-120", 120, "1–2 мин"),
        ("120-180", 180, "2–3 мин"),
        ("180-300", 300, "3–5 мин"),
        ("300-600", 600, "5–10 мин"),
        ("600+", .infinity, "10+ мин"),
    ]

    static func bucket(_ seconds: Double) -> String {
        durationBuckets.first { seconds < $0.upTo }?.key ?? "600+"
    }

    struct DurationBucket: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    /// Counts per bucket, in display order — the chart reads this directly.
    var durationHistogram: [DurationBucket] {
        Self.durationBuckets.map { bucket in
            DurationBucket(
                id: bucket.key,
                label: bucket.label,
                count: days.values.reduce(0) { $0 + ($1.durations[bucket.key] ?? 0) }
            )
        }
    }

    var totalMeasuredDictations: Int {
        durationHistogram.reduce(0) { $0 + $1.count }
    }

    /// Median length, interpolated inside the bucket that holds the middle
    /// recording. Buckets are all we keep, so this is an estimate and the label
    /// says "≈" — storing every duration to get one exact number isn't worth it.
    var medianSeconds: Double {
        let counts = durationHistogram.map(\.count)
        let total = counts.reduce(0, +)
        guard total > 0 else { return 0 }

        var seen = 0
        for (index, count) in counts.enumerated() where count > 0 {
            if seen + count >= (total + 1) / 2 {
                let bucket = Self.durationBuckets[index]
                let lower = index == 0 ? 0 : Self.durationBuckets[index - 1].upTo
                // The open-ended bucket has no upper edge to interpolate towards.
                guard bucket.upTo.isFinite else { return lower }
                let position = Double((total + 1) / 2 - seen) / Double(count)
                return lower + (bucket.upTo - lower) * position
            }
            seen += count
        }
        return 0
    }

    /// Shares of the three coarse groups under the chart: up to 30 s, 30 s to
    /// 3 min, longer.
    var durationGroups: [(label: String, share: Double)] {
        let counts = durationHistogram
        let total = counts.reduce(0) { $0 + $1.count }
        guard total > 0 else {
            return [("до 30 с", 0), ("30 с – 3 мин", 0), ("дольше 3 мин", 0)]
        }
        func share(_ ids: [String]) -> Double {
            Double(counts.filter { ids.contains($0.id) }.reduce(0) { $0 + $1.count }) / Double(total)
        }
        return [
            ("до 30 с", share(["0-5", "5-15", "15-30"])),
            ("30 с – 3 мин", share(["30-60", "60-120", "120-180"])),
            ("дольше 3 мин", share(["180-300", "300-600", "600+"])),
        ]
    }

    /// The longest dictation ever, in seconds.
    var longestSeconds: Double {
        days.values.map(\.maxSeconds).max() ?? 0
    }

    /// The same in minutes — what the achievements count in.
    var longestMinutes: Double {
        longestSeconds / 60
    }

    /// Dictations shorter than fifteen seconds, all time.
    var shortDictations: Int {
        durationHistogram
            .filter { $0.id == "0-5" || $0.id == "5-15" }
            .reduce(0) { $0 + $1.count }
    }

    /// How many buckets have anything in them.
    var filledBuckets: Int {
        durationHistogram.filter { $0.count > 0 }.count
    }

    /// The most speech in a single day, in minutes.
    var bestMinutesInDay: Double {
        (days.values.map(\.seconds).max() ?? 0) / 60
    }

    // MARK: - Records

    var totalAsks: Int {
        days.values.reduce(0) { $0 + $1.asks }
    }

    var totalScreens: Int {
        days.values.reduce(0) { $0 + $1.screens }
    }

    var bestAskWords: Int {
        days.values.map(\.maxAskWords).max() ?? 0
    }

    var bestWordsPerMinute: Double {
        days.values.map(\.maxWordsPerMinute).max() ?? 0
    }

    var bestWordsInDictation: Int {
        days.values.map(\.maxWords).max() ?? 0
    }

    var bestWordsInDay: Int {
        days.values.map(\.words).max() ?? 0
    }

    var bestDictationsInDay: Int {
        days.values.map(\.dictations).max() ?? 0
    }

    // MARK: - Charts

    struct DayPoint: Identifiable {
        let id: String
        let date: Date
        let words: Int
    }

    /// Words per day for the chart, oldest first; days with no dictations are zeros.
    func recentDays(_ count: Int = 14) -> [DayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let key = Self.dayKey(date)
            return DayPoint(id: key, date: date, words: days[key]?.words ?? 0)
        }
    }

    /// Dictations by hour of the day, 24 buckets. Empty for days recorded before
    /// hour tracking was added — the heat map fills in from now on.
    var hourly: [Int] {
        var buckets = [Int](repeating: 0, count: 24)
        for day in days.values {
            for (hour, count) in day.hours {
                guard let index = Int(hour), (0..<24).contains(index) else { continue }
                buckets[index] += count
            }
        }
        return buckets
    }

    /// Dictated at least once between 05:00 and 08:00.
    var hasEarlyBird: Bool {
        hourly[5..<8].contains { $0 > 0 }
    }

    /// Dictated at least once between 00:00 and 04:00.
    var hasNightOwl: Bool {
        hourly[0..<4].contains { $0 > 0 }
    }

    /// Dictated at least once on a Saturday or Sunday.
    var hasWeekend: Bool {
        let calendar = Calendar.current
        return days.keys.contains { key in
            guard let date = Self.dayFormatter.date(from: key) else { return false }
            return calendar.isDateInWeekend(date)
        }
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
