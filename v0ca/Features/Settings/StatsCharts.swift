import SwiftUI

/// Dictations by length, from the "Расширенная статистика" module. Per the
/// "Настройки · Статистика" mockup: the same heat ladder as the hour map, laid
/// out as nine columns with the share printed inside each one.
struct StatsDurationChart: View {
    let buckets: [StatsStore.DurationBucket]
    let median: Double
    let longest: Double
    let groups: [(label: String, share: Double)]

    @Environment(\.colorScheme) private var colorScheme

    private var peak: Int { buckets.map(\.count).max() ?? 0 }
    private var total: Int { buckets.reduce(0) { $0 + $1.count } }

    var body: some View {
        DSCard(title: L("Длина записи"), caption: caption, muted: total == 0) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(buckets) { bucket in
                    column(bucket)
                }
            }
            .overlay(alignment: .center) {
                if total == 0 {
                    Text(L("Появится после первой записи"))
                        .font(Tokens.sans(12.5))
                        .foregroundStyle(Tokens.text3)
                }
            }

            Divider()
                .overlay(Tokens.surface2)
                .padding(.top, 2)

            HStack(spacing: 22) {
                ForEach(groups, id: \.label) { group in
                    footerValue(
                        total == 0 ? "—" : "\(Int((group.share * 100).rounded()))%",
                        caption: group.label,
                        accented: leader == group.label
                    )
                }
                footerValue(
                    longest > 0 ? Self.duration(longest) : "—",
                    caption: "самая долгая",
                    accented: false
                )
            }
        }
    }

    private func column(_ bucket: StatsStore.DurationBucket) -> some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color(for: bucket))
                .frame(height: 64)
                .overlay(alignment: .bottom) {
                    if total > 0 {
                        Text("\(Int((Double(bucket.count) / Double(total) * 100).rounded()))%")
                            .font(Tokens.mono(12.5, weight: .medium))
                            .foregroundStyle(labelColor(for: bucket))
                            .padding(.bottom, 7)
                    }
                }
            Text(L(bucket.label))
                .font(Tokens.mono(10.5, weight: .medium))
                .foregroundStyle(
                    bucket.count == peak && peak > 0 ? Tokens.accentHover : Tokens.text3
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }

    /// The busiest of the three groups — the only accented number in the footer.
    private var leader: String? {
        guard total > 0 else { return nil }
        return groups.max { $0.share < $1.share }?.label
    }

    private var caption: String {
        guard total > 0 else { return "" }
        return L("%@ записей · медиана ≈ %@", "\(total)", Self.seconds(median))
    }

    private func footerValue(_ value: String, caption: String, accented: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value)
                .font(Tokens.mono(17, weight: .medium))
                .foregroundStyle(accented ? Tokens.accentHover : Tokens.text)
            Text(L(caption))
                .font(Tokens.sans(12.5))
                .foregroundStyle(Tokens.text3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Same ladder as the hour map, measured against the tallest bucket.
    private func color(for bucket: StatsStore.DurationBucket) -> Color {
        guard bucket.count > 0, peak > 0 else { return Tokens.surface2 }
        return Tokens.accent.opacity(Self.opacities(dark: colorScheme == .dark)[step(bucket)])
    }

    /// The percentage sits on the fill, so it follows the fill's darkness.
    private func labelColor(for bucket: StatsStore.DurationBucket) -> Color {
        guard bucket.count > 0, peak > 0 else { return Tokens.text3 }
        return switch step(bucket) {
        case 4...: Tokens.textOnAccent
        case 2...3: Tokens.text
        case 1: Tokens.text2
        default: Tokens.text3
        }
    }

    private func step(_ bucket: StatsStore.DurationBucket) -> Int {
        let fraction = Double(bucket.count) / Double(peak)
        return switch fraction {
        case 1: 6
        case 0.76...: 5
        case 0.51...: 4
        case 0.31...: 3
        case 0.16...: 2
        case 0.06...: 1
        default: 0
        }
    }

    private static func opacities(dark: Bool) -> [Double] {
        dark
            ? [0.18, 0.28, 0.40, 0.55, 0.72, 0.86, 1]
            : [0.10, 0.20, 0.34, 0.50, 0.70, 0.85, 1]
    }

    /// "24 с" / "1,5 мин" — the median, where seconds are the natural unit.
    private static func seconds(_ value: Double) -> String {
        value < 60
            ? L("%@ с", "\(Int(value.rounded()))")
            : L("%@ мин", String(format: "%.1f", value / 60))
    }

    /// "6:09" — the longest recording, where minutes are.
    private static func duration(_ value: Double) -> String {
        String(format: "%d:%02d", Int(value) / 60, Int(value) % 60)
    }
}

/// Words per day over the last two weeks. The peak is deliberately *not* accented —
/// the accent is reserved for today's bar being the darkest one on the card.
struct StatsBarChart: View {
    let points: [StatsStore.DayPoint]

    private var peak: Int { points.map(\.words).max() ?? 0 }

    var body: some View {
        DSCard(
            title: L("Слов по дням"),
            caption: L("Последние %@ дней", "\(points.count)"),
            muted: peak == 0
        ) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(points) { point in
                    column(point)
                }
            }
            .frame(height: 150)
            .overlay(alignment: .center) {
                if peak == 0 {
                    Text(L("Появится после первой записи"))
                        .font(Tokens.sans(12.5))
                        .foregroundStyle(Tokens.text3)
                }
            }
        }
    }

    private func column(_ point: StatsStore.DayPoint) -> some View {
        let fraction = peak > 0 ? Double(point.words) / Double(peak) : 0
        // A day well below the peak is muted so the shape of the fortnight reads
        // at a glance; today is the darkest bar regardless of its size.
        let quiet = fraction > 0 && fraction < 0.15
        let today = Calendar.current.isDateInToday(point.date)
        let fill: Color = if point.words == 0 {
            Tokens.surface2
        } else if today {
            Tokens.text
        } else if quiet {
            Tokens.surface2
        } else {
            Tokens.border
        }
        let labelColor: Color = today ? Tokens.text : (quiet ? Tokens.controlBorder : Tokens.text3)

        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(point.words > 0 ? StatsFormat.compact(point.words) : " ")
                .font(Tokens.mono(11, weight: .medium))
                .foregroundStyle(labelColor)
            UnevenRoundedRectangle(
                topLeadingRadius: 6, bottomLeadingRadius: 3,
                bottomTrailingRadius: 3, topTrailingRadius: 6
            )
            .fill(fill)
            // 3pt keeps empty days visible as a hairline instead of vanishing.
            .frame(height: max(3, fraction * 108))
            Text(StatsFormat.weekday(point.date))
                .font(Tokens.mono(11, weight: .medium))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Dictations by hour of the day. Steps are shares of the *peak* hour, not of the
/// total: across 24 buckets a share-of-total ladder would leave everything pale.
struct StatsHeatmap: View {
    let hourly: [Int]

    @Environment(\.colorScheme) private var colorScheme

    private var peak: Int { hourly.max() ?? 0 }
    private var total: Int { hourly.reduce(0, +) }

    var body: some View {
        DSCard(
            title: L("Когда вы диктуете"),
            caption: peakCaption,
            muted: total == 0
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 3) {
                    ForEach(0..<24, id: \.self) { hour in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color(for: hour))
                    }
                }
                .frame(height: 26)

                HStack(spacing: 0) {
                    ForEach(["00", "06", "12", "18", "24"], id: \.self) { mark in
                        Text(mark)
                            .font(Tokens.mono(11, weight: .medium))
                            .foregroundStyle(total == 0 ? Tokens.controlBorder : Tokens.text3)
                            .frame(maxWidth: .infinity, alignment: mark == "00"
                                ? .leading : (mark == "24" ? .trailing : .center))
                    }
                }
            }

            Divider()
                .overlay(Tokens.surface2)
                .padding(.top, 2)

            HStack(spacing: 22) {
                ForEach(Self.partsOfDay, id: \.title) { part in
                    let share = self.share(part.range)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(total == 0 ? "—" : "\(Int((share * 100).rounded()))%")
                            .font(Tokens.mono(17, weight: .medium))
                            .foregroundStyle(leader == part.title ? Tokens.accentHover : Tokens.text)
                        Text(L(part.title))
                            .font(Tokens.sans(12.5))
                            .foregroundStyle(Tokens.text3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private static let partsOfDay: [(title: String, range: Range<Int>)] = [
        ("утро", 6..<12), ("день", 12..<18), ("вечер", 18..<24), ("ночь", 0..<6),
    ]

    private func share(_ range: Range<Int>) -> Double {
        guard total > 0 else { return 0 }
        return Double(hourly[range].reduce(0, +)) / Double(total)
    }

    /// The busiest part of the day — the only accented number in the footer.
    private var leader: String? {
        guard total > 0 else { return nil }
        return Self.partsOfDay.max { share($0.range) < share($1.range) }?.title
    }

    private var peakCaption: String {
        guard total > 0, let hour = hourly.firstIndex(of: peak) else {
            return L("Пик — нет данных")
        }
        return L("Пик — %@", String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24))
    }

    private func color(for hour: Int) -> Color {
        let count = hourly[hour]
        // No data reads as neutral gray, never as a faint accent: an empty hour
        // must not look like "a little".
        guard count > 0, peak > 0 else { return Tokens.surface2 }
        let fraction = Double(count) / Double(peak)
        let step: Int = switch fraction {
        case 1: 6
        case 0.76...: 5
        case 0.51...: 4
        case 0.31...: 3
        case 0.16...: 2
        case 0.06...: 1
        default: 0
        }
        return Tokens.accent.opacity(Self.opacities(dark: colorScheme == .dark)[step])
    }

    /// The mockup ladder is calibrated for white; on a dark surface the lowest
    /// steps disappear, so they start higher.
    private static func opacities(dark: Bool) -> [Double] {
        dark
            ? [0.18, 0.28, 0.40, 0.55, 0.72, 0.86, 1]
            : [0.10, 0.20, 0.34, 0.50, 0.70, 0.85, 1]
    }
}
