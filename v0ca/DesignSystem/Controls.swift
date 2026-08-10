import SwiftUI

/// Тумблер по макету «Настройки · Новые экраны»: трек 44×26, белая ручка 20px
/// с тенью, ход 3→21px, анимация 0.18s.
struct AccentToggle: View {
    @Binding var isOn: Bool
    /// Выключённый тумблер не реагирует на клик и показан приглушённым.
    var enabled: Bool = true

    var body: some View {
        Button {
            guard enabled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? Tokens.accent : Tokens.cardBorder)
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(Tokens.knob)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .offset(x: isOn ? 21 : 3)
            }
            .opacity(enabled ? 1 : 0.45)
        }
        .pointerCursor(active: enabled)
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
    }
}

/// Переключатель-табы: серая капсула-трек, активный сегмент — белая пилюля с тенью.
/// Для выбора из 2–3 равнозначных вариантов, где дропдаун избыточен.
struct DSSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Tokens.surface2, in: Capsule())
    }

    private func segment(_ option: (value: Value, label: String)) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = option.value
            }
        } label: {
            Text(option.label)
                .font(Tokens.sans(13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Tokens.text : Tokens.text3)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background {
                    if isSelected {
                        // raised: в тёмной теме активный сегмент светлее трека,
                        // а не темнее (surface там темнее surface2).
                        Capsule()
                            .fill(Tokens.raised)
                            .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Радиокружок (каталог моделей): выбранный — толстое акцентное кольцо 5.5,
/// иначе тонкое серое 1.5. Сам по себе не кликабелен — клик обрабатывает строка.
struct DSRadio: View {
    let selected: Bool

    var body: some View {
        Circle()
            .strokeBorder(
                selected ? Tokens.accent : Tokens.controlBorderHover,
                lineWidth: selected ? 5.5 : 1.5
            )
            .frame(width: 18, height: 18)
    }
}
