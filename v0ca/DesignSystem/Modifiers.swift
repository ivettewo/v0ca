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

    /// Текстовый курсор (I-beam) при наведении — для текстовых полей.
    func textCursor() -> some View {
        modifier(TextCursorModifier())
    }

    /// Снимает фокус с текстового поля кликом вне его: пока поле в фокусе,
    /// локальный монитор ловит клики и, если попали не в текст, сбрасывает фокус.
    func unfocusOnOutsideClick(_ focused: FocusState<Bool>.Binding) -> some View {
        modifier(UnfocusOnOutsideClickModifier(focused: focused))
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
    func body(content: Content) -> some View {
        content.modifier(CursorModifier(cursor: .pointingHand))
    }
}

private struct TextCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(CursorModifier(cursor: .iBeam))
    }
}

private struct CursorModifier: ViewModifier {
    let cursor: NSCursor
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside {
                    guard !pushed else { return }
                    cursor.push()
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

/// Пока поле в фокусе, слушает mouseDown: клик, попавший не в текстовое вью
/// (редактор поля — NSTextView), снимает фокус. Монитор ставится только на время
/// фокуса и снимается при расфокусе/исчезновении вью.
private struct UnfocusOnOutsideClickModifier: ViewModifier {
    var focused: FocusState<Bool>.Binding
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onChange(of: focused.wrappedValue) { _, isFocused in
                isFocused ? install() : remove()
            }
            .onDisappear(perform: remove)
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            if let contentView = event.window?.contentView {
                let point = contentView.convert(event.locationInWindow, from: nil)
                if !(contentView.hitTest(point) is NSTextView) {
                    focused.wrappedValue = false
                }
            }
            return event
        }
    }

    private func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
