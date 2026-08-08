import SwiftUI

/// Тумблер по дизайну: трек 38×22, белая ручка 18px, ход 2→18px, анимация 0.18s.
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
                    .fill(isOn ? Tokens.accent : Color(hex: 0xD3D3D8))
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .offset(x: isOn ? 18 : 2)
            }
            .opacity(enabled ? 1 : 0.45)
        }
        .pointerCursor(active: enabled)
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
    }
}

/// Переключатель-табы: серый трек, активный сегмент — белая «пилюля» с рамкой.
/// Для выбора из 2–3 равнозначных вариантов, где дропдаун избыточен.
struct DSSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Tokens.surface2, in: RoundedRectangle(cornerRadius: 9))
    }

    private func segment(_ option: (value: Value, label: String)) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = option.value
            }
        } label: {
            Text(option.label)
                .font(Tokens.sans(12.5, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Tokens.text : Tokens.text2)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Tokens.surface)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Tokens.border, lineWidth: 1))
                            .shadow(color: .black.opacity(0.06), radius: 1.5, y: 1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 7))
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
                selected ? Tokens.accent : Color(hex: 0xC9C9CF),
                lineWidth: selected ? 5.5 : 1.5
            )
            .frame(width: 18, height: 18)
    }
}
