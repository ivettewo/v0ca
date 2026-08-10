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

    private var statsCard: some View {
        HStack(spacing: 22) {
            statColumn(Self.compact(stats.totalWords), caption: L("Слов расшифровано"))
            columnDivider
            statColumn(daysLabel(stats.streakDays), caption: L("Подряд"))
            columnDivider
            statColumn(Self.grouped(stats.averageWordsPerDay), caption: L("Слов в день в среднем"))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: Tokens.radiusCard).stroke(Tokens.cardBorder, lineWidth: 1))
    }

    private func statColumn(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Tokens.mono(26, weight: .medium))
                .kerning(-0.5)
                .foregroundStyle(Tokens.text)
            Text(caption)
                .font(Tokens.sans(12.5))
                .foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Tokens.surface2)
            .frame(width: 1)
    }

    // MARK: - Formatting

    /// From 1000 up — compact with one decimal: 342.7k (as in the mockup).
    private static func compact(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        let thousands = Double(value) / 1000
        let formatted = String(format: "%.1f", thousands)
        return "\(formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted)k"
    }

    /// Space-separated thousands: 1 240.
    private static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "18 дней" with Russian plural forms; in English just day/days.
    private func daysLabel(_ count: Int) -> String {
        if AppLanguage.shared.code == .en {
            return count == 1 ? "1 day" : "\(count) days"
        }
        let mod10 = count % 10
        let mod100 = count % 100
        let word: String = if mod10 == 1, mod100 != 11 {
            "день"
        } else if (2...4).contains(mod10), !(12...14).contains(mod100) {
            "дня"
        } else {
            "дней"
        }
        return "\(count) \(word)"
    }
}
