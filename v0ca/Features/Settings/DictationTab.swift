import SwiftUI

/// "Dictation" tab per the "Settings · New screens" mockup, tab 00:
/// stats card (total words / streak / average) + today's records.
/// Stats come from StatsStore (per-day aggregates, independent of the trimmed history).
struct DictationTab: View {
    let coordinator: RecordingCoordinator

    @State private var playback = PlaybackController()

    private var stats: StatsStore { coordinator.stats }

    var body: some View {
        // LazyVStack, same as in History: with a long list for today only
        // visible rows are built, otherwise scrolling stutters.
        LazyVStack(alignment: .leading, spacing: 22) {
            statsCard
                .onDisappear { playback.stop() }

            let today = todayRecords
            if today.isEmpty {
                Text(L("Записей пока нет — продиктуйте что-нибудь."))
                    .font(Tokens.sans(12))
                    .foregroundStyle(Tokens.text3)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    SectionLabel(L("Сегодня"))
                    HistoryRecordsCard(coordinator: coordinator, records: today, playback: playback)
                }
            }
        }
    }

    private var todayRecords: [HistoryRecord] {
        coordinator.history.records.filter { Calendar.current.isDateInToday($0.date) }
    }

    // MARK: - Stats card

    /// The same card the Stats tab shows, minus the second row — formatting and
    /// layout live in StatsMetricsCard so the two tabs can't drift apart.
    private var statsCard: some View {
        StatsMetricsCard(rows: [[
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
                value: StatsFormat.grouped(stats.averageWordsPerDay)
            ),
        ]])
    }
}
