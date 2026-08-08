import AppKit
import SwiftUI

extension View {
    /// Оформление текстового поля по дизайн-системе: рамка + фокус-ринг
    /// (акцентная рамка `#E03E3E` и розовый ринг `0 0 0 3px #FCEBEB`).
    func dsFieldStyle(focused: Bool, radius: CGFloat = Tokens.radiusControl,
                      fill: Color = Tokens.surface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(focused ? Tokens.accent : Tokens.border, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(focused ? Tokens.accentSoft : .clear)
                    .padding(-3)
            )
    }

    /// Фон при наведении (для иконок-действий: hover-подсветка по макету).
    func hoverBackground(_ color: Color, radius: CGFloat = 7) -> some View {
        modifier(HoverBackgroundModifier(color: color, radius: radius))
    }

    /// Курсор-указатель (рука) при наведении — для кликабельных контролов.
    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }

    /// То же, но только когда `active == true` (для элементов, кликабельных условно).
    @ViewBuilder
    func pointerCursor(active: Bool) -> some View {
        if active {
            modifier(PointerCursorModifier())
        } else {
            self
        }
    }
}

private struct HoverBackgroundModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(hovering ? color : .clear))
            .onHover { hovering = $0 }
    }
}

/// Пушит/попает `NSCursor.pointingHand` строго парно и чистит стек, если вью
/// исчезает под курсором (иначе курсор «залипает» рукой).
private struct PointerCursorModifier: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    guard !pushed else { return }
                    NSCursor.pointingHand.push()
                    pushed = true
                } else {
                    guard pushed else { return }
                    NSCursor.pop()
                    pushed = false
                }
            }
            .onDisappear {
                if pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
    }
}
