import SwiftUI

/// One number with a caption in the metrics card.
struct StatsMetric: Identifiable {
    let caption: String
    let value: String
    /// The "time saved" column is the only accented number on the screen.
    var accented = false

    var id: String { caption }
}

/// Metrics card per the "New screens · Stats" mockup: rows of three columns
/// separated by hairlines. The Dictation tab shows a single row; the Stats tab
/// merges both rows into one container, so the six numbers read as one block.
struct StatsMetricsCard: View {
    let rows: [[StatsMetric]]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    RowDivider()
                }
                HStack(spacing: 22) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { column, metric in
                        if column > 0 {
                            Rectangle()
                                .fill(Tokens.surface2)
                                .frame(width: 1)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.value)
                                .font(Tokens.mono(26, weight: .medium))
                                .kerning(-0.5)
                                .foregroundStyle(metric.accented ? Tokens.accentHover : Tokens.text)
                            Text(metric.caption)
                                .font(Tokens.sans(12.5))
                                .foregroundStyle(Tokens.text3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 22)
        .dsCard()
    }
}

/// Number and date formatting shared by the Dictation and Stats tabs.
/// Formatters are built once and reused: the Stats tab formats a few hundred
/// numbers per redraw, and allocating a NumberFormatter each time is the one
/// thing on this screen that would actually cost measurable time.
@MainActor
enum StatsFormat {
    /// From 1000 up — compact with one decimal: 342.7k (as in the mockup).
    static func compact(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        let thousands = Double(value) / 1000
        let formatted = String(format: "%.1f", thousands)
        return "\(formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted)k"
    }

    /// Space-separated thousands: 1 240.
    static func grouped(_ value: Int) -> String {
        groupingFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "41,6 ч" — one decimal below ten hours, whole hours above.
    static func hours(_ seconds: Double) -> String {
        let value = seconds / 3600
        guard value > 0 else { return "0 " + L("ч") }
        decimalFormatter.maximumFractionDigits = value >= 10 ? 0 : 1
        let number = decimalFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(number) " + L("ч")
    }

    /// Short weekday name in the interface language, not the system one.
    static func weekday(_ date: Date) -> String {
        let code = AppLanguage.shared.code
        if weekdayLanguage != code {
            // setLocalizedDateFormatFromTemplate is expensive; redo it only when
            // the interface language actually changes.
            weekdayFormatter.locale = Locale(identifier: code.rawValue)
            weekdayFormatter.setLocalizedDateFormatFromTemplate("EEEEEE")
            weekdayLanguage = code
        }
        return weekdayFormatter.string(from: date).capitalized
    }

    private static let groupingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let weekdayFormatter = DateFormatter()
    private static var weekdayLanguage: AppLanguage.Code?

    /// "18 дней" with Russian plural forms; in English just day/days.
    static func days(_ count: Int) -> String {
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
