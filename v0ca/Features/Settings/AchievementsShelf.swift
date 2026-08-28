import SwiftUI

/// Achievements grouped into sections. The mockup keeps every row in one card,
/// but with the full catalog that card runs metres long — one card per group
/// matches the rest of the settings and stays readable.
struct AchievementsShelf: View {
    let achievements: [Achievement]

    private var unlocked: Int { achievements.filter(\.unlocked).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionLabel(L("Достижения · %@ из %@", "\(unlocked)", "\(achievements.count)"))

            ForEach(Achievement.Group.allCases, id: \.self) { group in
                let rows = achievements.filter { $0.group == group }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(
                            L(group.title) + " · "
                                + L("%@ из %@", "\(rows.filter(\.unlocked).count)", "\(rows.count)")
                        )
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    RowDivider()
                                }
                                AchievementRow(achievement: item)
                            }
                        }
                        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.radiusCard)
                                .stroke(Tokens.cardBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusCard))
                    }
                }
            }
        }
    }
}

/// A single achievement: progress ring, title with caption, percentage.
/// Locked rows all share the same gray wash regardless of how far along they are —
/// progress lives in the ring and the percentage, not in the background.
struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 16) {
            ring
            VStack(alignment: .leading, spacing: 3) {
                Text(L(achievement.title))
                    .font(Tokens.sans(14, weight: .medium))
                    .foregroundStyle(achievement.unlocked ? Tokens.text : Tokens.text2)
                Text(achievement.caption)
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(achievement.unlocked ? Tokens.text2 : Tokens.text3)
            }
            Spacer(minLength: 16)
            Text("\(Int((achievement.fraction * 100).rounded(.down)))%")
                .font(Tokens.mono(12, weight: .medium))
                .foregroundStyle(achievement.unlocked ? Tokens.accentHover : Tokens.text3)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
    }

    @ViewBuilder
    private var background: some View {
        if achievement.unlocked {
            Color.clear
        } else {
            LinearGradient(
                stops: [
                    .init(color: Tokens.surface2, location: 0),
                    .init(color: Tokens.background, location: 0.34),
                    .init(color: Tokens.surface, location: 0.72),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    /// 52pt outer, 40pt inner — a 6pt ring drawn as a stroke, which is the same
    /// donut the mockup builds with a conic gradient.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Tokens.skeleton, lineWidth: 6)
            Circle()
                .trim(from: 0, to: achievement.fraction)
                .stroke(
                    achievement.unlocked ? Tokens.accent : Tokens.text3,
                    style: StrokeStyle(lineWidth: 6)
                )
                .rotationEffect(.degrees(-90))
            center
        }
        .frame(width: 46, height: 46)
    }

    /// Unlocked rows show the achievement's icon; locked measurable ones show how
    /// far along they are, and all-or-nothing ones keep a muted icon — "0/1"
    /// would say nothing.
    @ViewBuilder
    private var center: some View {
        if let label = achievement.progressLabel, !achievement.unlocked {
            Text(label)
                .font(Tokens.mono(label.count > 4 ? 10 : 12, weight: .medium))
                .foregroundStyle(Tokens.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 3)
        } else {
            Image(systemName: achievement.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(achievement.unlocked ? Tokens.accentHover : Tokens.controlBorder)
        }
    }
}
