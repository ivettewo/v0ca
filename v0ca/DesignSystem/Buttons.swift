import SwiftUI

// MARK: - Кнопка (дизайн-система, раздел 06)

/// Варианты кнопок из макета: primary / secondary / ghost / danger-soft / icon.
enum DSButtonVariant {
    case primary, secondary, ghost, dangerSoft, icon
}

/// Кнопка дизайн-системы: высота 36 (compact 28), капсула («Настройки · Новые
/// экраны» — все кнопки пилюли), живой hover.
struct DSButton<Label: View>: View {
    var variant: DSButtonVariant = .secondary
    var compact: Bool = false
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var hovering = false

    private var height: CGFloat { variant == .icon ? 36 : (compact ? 28 : 36) }
    private var radius: CGFloat { height / 2 }

    var body: some View {
        Button(action: action) {
            label()
                .font(Tokens.sans(compact ? 12 : 13, weight: .medium))
                .foregroundStyle(foreground)
                .frame(height: height)
                .modifier(WidthModifier(width: variant == .icon ? height : nil,
                                        padding: variant == .icon ? 0 : (compact ? 12 : 18)))
                .background(background, in: RoundedRectangle(cornerRadius: radius))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(borderColor, lineWidth: hasBorder ? 1 : 0)
                )
                .contentShape(RoundedRectangle(cornerRadius: radius))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
    }

    private var hasBorder: Bool { variant == .secondary || variant == .icon }

    private var background: Color {
        switch variant {
        case .primary: hovering ? Tokens.accentHover : Tokens.accent
        case .secondary, .icon: hovering ? Tokens.background : Tokens.surface
        case .ghost: hovering ? Tokens.surface2 : .clear
        case .dangerSoft: hovering ? Tokens.accentSoftHover : Tokens.accentSoft
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: Tokens.textOnAccent
        case .secondary: Tokens.text
        case .icon: hovering ? Tokens.text : Tokens.text2
        case .ghost: hovering ? Tokens.text : Tokens.text2
        case .dangerSoft: Tokens.accentHover
        }
    }

    private var borderColor: Color { hovering ? Tokens.controlBorderHover : Tokens.controlBorder }
}

extension DSButton where Label == Text {
    /// Текстовая кнопка по строке.
    init(_ title: String, variant: DSButtonVariant = .secondary, compact: Bool = false,
         action: @escaping () -> Void) {
        self.init(variant: variant, compact: compact, action: action) { Text(title) }
    }
}

/// Ширина/паддинг: icon-кнопка квадратная, остальные — по горизонтальному паддингу.
private struct WidthModifier: ViewModifier {
    let width: CGFloat?
    let padding: CGFloat
    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width)
        } else {
            content.padding(.horizontal, padding)
        }
    }
}

/// Компактная иконка-действие 28×28 (карточки истории): без рамки,
/// hover-подсветка фоном, тултип. Не путать с `DSButton(.icon)` — тот 36×36
/// с рамкой, для тулбаров.
struct DSIconAction: View {
    let symbol: String
    let help: String
    var tint: Color = Tokens.text2
    var hoverAccent: Bool = false
    let action: () -> Void

    init(_ symbol: String, help: String, tint: Color = Tokens.text2,
         hoverAccent: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.tint = tint
        self.hoverAccent = hoverAccent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .hoverBackground(hoverAccent ? Tokens.accentSoft : Tokens.surface2)
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(help)
    }
}
