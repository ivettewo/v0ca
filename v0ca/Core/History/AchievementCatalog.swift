import Foundation
import OSLog

/// The shelf as data: `Resources/AchievementCatalog.json`, loaded like
/// `ModelCatalog.json`. See docs/STATS.md.
///
/// A row names one of three sources and nothing else decides its progress:
/// `metric` + `goal` for anything countable, `flag` for an event only the app can
/// witness, `condition` for a fact derived from the current state. The names
/// resolve against registries in `AchievementsStore`; an unknown name is skipped
/// rather than fatal — the same rule that keeps `achievements.json` safe from a
/// flag this build has never heard of.
struct AchievementCatalog: Decodable {
    struct Group: Decodable, Identifiable {
        let id: String
        /// Russian base string — the key for `L()`.
        let title: String
    }

    struct Entry: Decodable, Identifiable {
        let id: String
        let group: String
        let title: String
        let icon: String
        /// Countable source: a name from the metric registry.
        var metric: String?
        var goal: Double?
        /// For a goal that isn't a constant — "every provider" grows with the
        /// catalog. Names a metric, same registry.
        var goalMetric: String?
        /// All-or-nothing source: a persisted flag.
        var flag: String?
        /// All-or-nothing source: a fact recomputed from the current state.
        var condition: String?
        /// Belongs to a module: the row is on the shelf only while that module is
        /// on. Progress is kept — off means invisible, not wiped.
        var module: String?
        /// How the number reads: "count" (default), "hours", "plain".
        var format: String?
        /// Shown while locked. A `%@` in it is filled with the formatted goal.
        let caption: String
        /// Overrides the default "done" caption; `%@` is the reached value.
        var doneCaption: String?
    }

    let groups: [Group]
    let achievements: [Entry]

    private static let log = Logger(category: "AchievementCatalog")

    static let shared: AchievementCatalog = load()

    private static func load() -> AchievementCatalog {
        guard let url = Bundle.main.url(forResource: "AchievementCatalog", withExtension: "json") else {
            log.error("AchievementCatalog.json не найден в бандле")
            return AchievementCatalog(groups: [], achievements: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AchievementCatalog.self, from: data)
        } catch {
            log.error("AchievementCatalog.json не прочитан: \(error)")
            return AchievementCatalog(groups: [], achievements: [])
        }
    }
}
