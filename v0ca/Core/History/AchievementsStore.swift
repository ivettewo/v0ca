import Foundation
import KeyboardShortcuts
import Observation
import OSLog

/// One row on the achievements shelf. Built on the fly from StatsStore and the
/// current settings — only the handful of things the app would otherwise forget
/// are persisted (see `AchievementsStore.Flag`).
struct Achievement: Identifiable {
    let id: String
    /// Group id from the catalog; the shelf takes the order and titles from there.
    let group: String
    let title: String
    /// Caption under the title: what to do while locked, what was done once unlocked.
    let caption: String
    let icon: String
    /// Progress towards the goal, 0…1.
    let fraction: Double
    /// Short "12/30" for the middle of the ring. Nil for all-or-nothing
    /// achievements — there is no progress to show, so the ring holds a muted icon.
    let progressLabel: String?

    var unlocked: Bool { fraction >= 1 }
}

/// Achievement flags that can't be recovered from the current state.
/// Everything else — a changed hotkey, a second model, a picked microphone —
/// is derived from settings, so a long-time user doesn't open the tab to an empty shelf.
@MainActor
@Observable
final class AchievementsStore {
    enum Flag: String, Codable, CaseIterable {
        case playback
        case retranscribe
        case favorite
        case engineWhisperKit
        case engineFluidAudio
        /// A screenshot sent without saying anything.
        case silentScreen
        /// Backed out during the countdown, before the question left the Mac.
        case askCancelled
        /// Asked the same question again.
        case regenerated
        /// Waited out a long answer instead of giving up.
        case patientAnswer
        // One per provider that has actually answered something.
        case providerOpenAI
        case providerAnthropic
        case providerXai
        case providerGoogle
        case providerQwen
    }

    /// Which flag marks "this provider has answered".
    static func flag(forProvider id: String) -> Flag? {
        switch id {
        case "openai": .providerOpenAI
        case "anthropic": .providerAnthropic
        case "xai": .providerXai
        case "google": .providerGoogle
        case "qwen": .providerQwen
        default: nil
        }
    }

    private(set) var flags: Set<Flag> = []

    @ObservationIgnored private let log = Logger(category: "AchievementsStore")

    private static var fileURL: URL {
        HistoryStore.baseFolder.appendingPathComponent("achievements.json")
    }

    init() {
        load()
    }

    func mark(_ flag: Flag) {
        guard !flags.contains(flag) else { return }
        flags.insert(flag)
        save()
    }

    func mark(engine: EngineKind) {
        mark(engine == .whisperKit ? .engineWhisperKit : .engineFluidAudio)
    }

    // MARK: - Catalog

    /// The full shelf, in the order the catalog file lists it. Progress is
    /// recomputed on every read — cheap enough, and it keeps the tab in sync
    /// with stats without extra plumbing.
    ///
    /// A row whose metric, flag or condition this build doesn't know is dropped:
    /// a catalog from a newer version must not empty the shelf.
    func all(stats: StatsStore, models: ModelManager, history: HistoryStore) -> [Achievement] {
        let metrics = metrics(stats: stats, models: models)
        let conditions = conditions(stats: stats, history: history)

        return AchievementCatalog.shared.achievements.compactMap { entry in
            if let name = entry.flag {
                guard let flag = Flag(rawValue: name) else { return nil }
                return flagged(entry, done: flags.contains(flag))
            }
            if let name = entry.condition {
                guard let value = conditions[name] else { return nil }
                return flagged(entry, done: value)
            }
            guard let name = entry.metric, let value = metrics[name] else { return nil }
            let goal = entry.goalMetric.flatMap { metrics[$0] } ?? entry.goal
            guard let goal, goal > 0 else { return nil }
            return measured(entry, value: value, goal: goal)
        }
    }

    /// Everything countable, by the name the catalog uses.
    private func metrics(stats: StatsStore, models: ModelManager) -> [String: Double] {
        let answered = ProviderCatalog.all
            .compactMap { Self.flag(forProvider: $0.id) }
            .filter(flags.contains)
            .count
        let downloaded = models.itemStates.values.filter { $0 == .downloaded }.count
        let engines = [Flag.engineWhisperKit, .engineFluidAudio].filter(flags.contains).count

        return [
            "words": Double(stats.totalWords),
            "dictations": Double(stats.totalDictations),
            "streakDays": Double(stats.streakDays),
            "bestWordsInDay": Double(stats.bestWordsInDay),
            "bestDictationsInDay": Double(stats.bestDictationsInDay),
            "bestWordsInDictation": Double(stats.bestWordsInDictation),
            "bestWordsPerMinute": stats.bestWordsPerMinute,
            "savedHours": stats.savedSeconds / 3600,
            "spokenHours": stats.totalSeconds / 3600,
            "asks": Double(stats.totalAsks),
            "screens": Double(stats.totalScreens),
            "bestAskWords": Double(stats.bestAskWords),
            "providersAnswered": Double(answered),
            "providersTotal": Double(ProviderCatalog.all.count),
            "downloadedModels": Double(downloaded),
            "enginesUsed": Double(engines),
        ]
    }

    /// Facts that are true or not, read from the current state rather than
    /// remembered. Flags are for what leaves no trace; these leave one.
    private func conditions(stats: StatsStore, history: HistoryStore) -> [String: Bool] {
        let defaults = UserDefaults.standard
        return [
            "earlyBird": stats.hasEarlyBird,
            "nightOwl": stats.hasNightOwl,
            "weekend": stats.hasWeekend,
            "askedBothWays": stats.totalAsks > 0 && stats.totalScreens > 0,
            "hotkeyChanged": KeyboardShortcuts.Name.toggleRecording.shortcut
                != KeyboardShortcuts.Name.toggleRecording.defaultShortcut,
            "fnHotkey": Prefs.toggleRecordingUsesFn,
            "styleChanged": AccentStore.shared.hex.uppercased() != "E03E3E"
                || defaults.string(forKey: Prefs.Key.appTheme) != nil,
            "micPicked": defaults.string(forKey: Prefs.Key.inputDeviceUID) != nil,
            "languageChanged": defaults.string(forKey: Prefs.Key.interfaceLanguage) != nil,
            "hasFavorite": flags.contains(.favorite) || history.records.contains(where: \.favorite),
            "onboardingDone": Prefs.onboardingDone,
        ]
    }

    // MARK: - Builders

    /// Measurable achievement: the ring shows the current value while locked.
    /// `format` decides how both the value and the goal read — plain counts are
    /// grouped ("1 240"), hours get one decimal below ten.
    private func measured(_ entry: AchievementCatalog.Entry, value: Double, goal: Double) -> Achievement {
        let done = value >= goal
        let format = entry.format ?? "count"
        let label = Self.label(value, format: format)

        let caption: String
        if done, let template = entry.doneCaption {
            caption = L(template, label)
        } else if done {
            caption = Self.doneCaption(value: value, goal: goal, format: format)
        } else if entry.caption.contains("%@") {
            caption = L(entry.caption, Self.label(goal, format: format))
        } else {
            caption = L(entry.caption)
        }

        return Achievement(
            id: entry.id, group: entry.group, title: entry.title,
            caption: caption,
            icon: entry.icon,
            fraction: min(1, value / goal),
            // Only the current value: 52pt of ring can't hold "10.2k/500k", and
            // the goal is already spelled out in the caption.
            progressLabel: done ? nil : Self.ringLabel(value, format: format)
        )
    }

    /// All-or-nothing achievement: no progress to show, the ring keeps a muted icon.
    private func flagged(_ entry: AchievementCatalog.Entry, done: Bool) -> Achievement {
        Achievement(
            id: entry.id, group: entry.group, title: entry.title,
            caption: done ? L("Выполнено") : L(entry.caption),
            icon: entry.icon, fraction: done ? 1 : 0, progressLabel: nil
        )
    }

    private static func doneCaption(value: Double, goal: Double, format: String) -> String {
        switch format {
        case "hours":
            return L("%@ ч — выполнено", hours(value))
        default:
            // A goal of one is a yes/no thing — "400 out of 1" would read as nonsense.
            guard goal > 1 else { return L("Выполнено") }
            return L("%@ из %@ — выполнено", grouped(Int(value)), grouped(Int(goal)))
        }
    }

    /// Inside a caption: full and grouped.
    private static func label(_ value: Double, format: String) -> String {
        switch format {
        case "hours": hours(value)
        case "plain": "\(Int(value))"
        default: grouped(Int(value))
        }
    }

    /// Inside the ring: short enough for 52pt.
    private static func ringLabel(_ value: Double, format: String) -> String {
        switch format {
        case "hours": hours(value)
        case "plain": "\(Int(value))"
        default: compact(Int(value))
        }
    }

    // MARK: - Formatting

    /// Space-separated thousands: 1 240. Shared with the metrics card so the
    /// screen never shows the same number in two shapes.
    static func grouped(_ value: Int) -> String {
        StatsFormat.grouped(value)
    }

    /// Short form for the middle of the ring: 1.2k, 340k, 1M.
    static func compact(_ value: Int) -> String {
        value >= 1_000_000 ? "\(value / 1_000_000)M" : StatsFormat.compact(value)
    }

    private static func hours(_ value: Double) -> String {
        value >= 10 ? "\(Int(value))" : String(format: "%.1f", value)
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        do {
            // Decoded through raw strings: a name this build doesn't know about
            // is skipped instead of throwing and losing every earned flag.
            let names = try JSONDecoder().decode([String].self, from: data)
            flags = Set(names.compactMap(Flag.init(rawValue:)))
        } catch {
            log.error("Достижения не прочитаны: \(error)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: HistoryStore.baseFolder, withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(Array(flags))
            try data.write(to: Self.fileURL)
        } catch {
            log.error("Достижения не записаны: \(error)")
        }
    }
}
