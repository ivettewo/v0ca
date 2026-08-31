import SwiftUI

/// "Stats" tab per the "New screens · 05 Stats" mockup: six metrics in one card,
/// words per day, an hour-of-day heat map and the achievements shelf.
struct StatsTab: View {
    let coordinator: RecordingCoordinator

    private var stats: StatsStore { coordinator.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StatsMetricsCard(rows: [totals, effort])
            StatsBarChart(points: stats.recentDays())
            StatsHeatmap(hourly: stats.hourly)
            // Contributed by the "Расширенная статистика" module: no module, no
            // chart — and nothing was recorded for it either.
            if ModuleCatalog.isEnabled("stats") {
                StatsDurationChart(
                    buckets: stats.durationHistogram,
                    median: stats.medianSeconds,
                    longest: stats.longestSeconds,
                    groups: stats.durationGroups
                )
            }
            AchievementsShelf(
                achievements: coordinator.achievements.all(
                    stats: stats, models: coordinator.models, history: coordinator.history
                )
            )
        }
    }

    private var totals: [StatsMetric] {
        [
            StatsMetric(
                caption: L("Слов расшифровано"),
                value: StatsFormat.compact(stats.totalWords)
            ),
            StatsMetric(
                caption: L("Подряд"),
                value: StatsFormat.days(stats.streakDays)
            ),
            StatsMetric(
                caption: L("Слов в день в среднем"),
                value: stats.averageWordsPerDay > 0
                    ? StatsFormat.grouped(stats.averageWordsPerDay) : "—"
            ),
        ]
    }

    private var effort: [StatsMetric] {
        // Speech time and time saved only cover days recorded after the app
        // started counting characters and seconds — older days stay at zero.
        [
            StatsMetric(
                caption: L("Завершённых записей"),
                value: StatsFormat.grouped(stats.totalDictations)
            ),
            StatsMetric(
                caption: L("Времени речи"),
                value: StatsFormat.hours(stats.totalSeconds)
            ),
            StatsMetric(
                caption: L("Сэкономлено против набора"),
                value: stats.savedSeconds > 60 ? "≈ " + StatsFormat.hours(stats.savedSeconds) : "—",
                accented: stats.savedSeconds > 60
            ),
        ]
    }
}
