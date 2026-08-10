import SwiftUI

/// All-caps section header: 11.5/500, .12em letter spacing, muted, 4pt left inset.
/// Uppercases by itself — pass text in any case.
struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Tokens.sans(11.5, weight: .medium))
            .kerning(1.38)
            .foregroundStyle(Tokens.text3)
            .padding(.leading, 4)
    }
}

/// Settings section: all-caps header + white card with rows.
/// Card per the "Settings · New screens" mockup: radius 18, cardBorder stroke,
/// soft shadow, 20pt horizontal padding — rows and dividers span the full width.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(title)
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 20)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: Tokens.radiusCard).stroke(Tokens.cardBorder, lineWidth: 1))
        }
    }
}

/// Settings row: title (+ description) on the left, control on the right.
/// No horizontal insets of its own — the section card provides them (20pt padding).
struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.sans(14))
                    .foregroundStyle(Tokens.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.sans(12.5))
                        .foregroundStyle(Tokens.text3)
                }
            }
            Spacer(minLength: 16)
            trailing
        }
        .padding(.vertical, 15)
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().overlay(Tokens.surface2)
    }
}
