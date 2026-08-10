import SwiftUI

/// Капс-заголовок секции: 11.5/500, разрядка .12em, приглушённый, отступ слева 4.
/// Капсит сам — передавать можно в любом регистре.
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

/// Секция настроек: заголовок-капс + белая карточка со строками.
/// Карточка по макету «Настройки · Новые экраны»: радиус 18, рамка cardBorder,
/// мягкая тень, горизонтальный паддинг 20 — строки и разделители во всю ширину.
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

/// Строка настройки: название (+ описание) слева, контрол справа.
/// Горизонтальных отступов нет — их даёт карточка секции (паддинг 20).
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
