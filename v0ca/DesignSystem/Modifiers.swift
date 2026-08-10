import AppKit
import SwiftUI

extension View {
    /// Design-system text field styling: border + focus ring
    /// (accent `#E03E3E` border and pink `0 0 0 3px #FCEBEB` ring).
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

    /// Hover background (for icon actions: hover highlight per the mockup).
    func hoverBackground(_ color: Color, radius: CGFloat = 7) -> some View {
        modifier(HoverBackgroundModifier(color: color, radius: radius))
    }

    /// Pointing-hand cursor on hover — for clickable controls.
    func pointerCursor() -> some View {
        modifier(PointerCursorModifier())
    }

    /// Text cursor (I-beam) on hover — for text fields.
    func textCursor() -> some View {
        modifier(TextCursorModifier())
    }

    /// Unfocuses a text field on outside clicks: while the field is focused,
    /// a local monitor catches clicks and clears focus if they miss the text.
    func unfocusOnOutsideClick(_ focused: FocusState<Bool>.Binding) -> some View {
        modifier(UnfocusOnOutsideClickModifier(focused: focused))
    }

    /// Same, but only when `active == true` (for conditionally clickable elements).
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

/// Pushes/pops `NSCursor.pointingHand` in strict pairs and cleans up the stack
/// if the view disappears under the cursor (otherwise the hand cursor gets stuck).
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

/// While the field is focused, listens for mouseDown: a click that lands outside
/// a text view (the field editor is an NSTextView) clears focus. The monitor is
/// installed only while focused and removed on unfocus or view disappearance.
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
