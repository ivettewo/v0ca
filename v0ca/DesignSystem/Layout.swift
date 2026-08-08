import SwiftUI

/// Капс-заголовок секции: 11/500, разрядка 1.1, приглушённый. Капсит сам —
/// передавать можно в любом регистре.
struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(Tokens.sans(11, weight: .medium))
            .kerning(1.1)
            .foregroundStyle(Tokens.text3)
    }
}

/// Секция настроек: заголовок-капс + белая карточка со строками.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            VStack(spacing: 0) {
                content
            }
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: Tokens.radiusCard).stroke(Tokens.border, lineWidth: 1))
        }
    }
}

/// Строка настройки: название (+ описание) слева, контрол справа.
struct SettingRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.sans(13.5))
                    .foregroundStyle(Tokens.text)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.sans(11.5))
                        .foregroundStyle(Tokens.text3)
                }
            }
            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct RowDivider: View {
    var body: some View {
        Divider().overlay(Tokens.border.opacity(0.6)).padding(.leading, 16)
    }
}
