import AppKit
import SwiftUI

/// Dropdown per the "Settings · New screens" mockup: 36px capsule button sized
/// to its content; the open list is a fully custom floating panel (NSPanel)
/// with a pink highlight on the selected item, right-aligned to the button.
struct DesignDropdown<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    /// Width of the open list (the button sizes to its content).
    var width: CGFloat = 190
    /// SF Symbol left of the label (language filter in the model catalog).
    var icon: String?

    @State private var open = false
    @State private var anchor: NSView?
    @State private var panel = DropdownPanelController()

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.text2)
                }
                Text(currentLabel)
                    .font(Tokens.sans(13))
                    .foregroundStyle(Tokens.text)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.text3)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(height: 36)
            .background(Tokens.surface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(open ? Tokens.accent : Tokens.controlBorder, lineWidth: 1)
            )
            // Focus ring when open: box-shadow 0 0 0 3px #FCEBEB
            .background(
                Capsule()
                    .fill(open ? Tokens.accentSoft : .clear)
                    .padding(-3)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .background(AnchorReader { anchor = $0 })
        .onDisappear { panel.close() }
    }

    private func toggle() {
        if open {
            panel.close()
            return
        }
        guard let rect = anchor?.screenFrame else { return }
        open = true
        panel.onClose = { open = false }
        let list = DropdownList(
            options: options,
            selected: selection,
            width: width
        ) { picked in
            selection = picked
            panel.close()
        }
        panel.show(below: rect, width: width) { AnyView(list) }
    }
}

/// Open list: radius-14 card with a soft border, 32px items with radius 9;
/// the selected one gets a pink background + red text + checkmark, the rest hover.
private struct DropdownList<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    let selected: Value
    let width: CGFloat
    let onPick: (Value) -> Void

    var body: some View {
        VStack(spacing: 1) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selected
                Button {
                    onPick(option.value)
                } label: {
                    HStack(spacing: 8) {
                        Text(option.label)
                            .font(Tokens.sans(13))
                            .foregroundStyle(isSelected ? Tokens.accentHover : Tokens.text)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Tokens.accentHover)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(isSelected ? Tokens.accentSoft : .clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(5)
        .frame(width: width)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Tokens.cardBorder, lineWidth: 1))
    }
}

/// Captures the hosting NSView to compute the screen position for the list panel.
private struct AnchorReader: NSViewRepresentable {
    let onView: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onView(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private extension NSView {
    var screenFrame: NSRect? {
        guard let window else { return nil }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}

/// Floating list panel: borderless NSPanel with no system chrome,
/// closes on selection and on outside clicks.
@MainActor
final class DropdownPanelController {
    private var panel: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    var onClose: (() -> Void)?

    /// Small transparent inset around the card inside the panel (no shadow).
    private let shadowPad: CGFloat = 4

    func show(below anchor: NSRect, width: CGFloat, content: () -> AnyView) {
        close(fireCallback: false)

        let hosting = NSHostingView(rootView: content().padding(shadowPad))
        hosting.layout()
        let size = hosting.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.contentView = hosting

        // The card is right-aligned under the button (the capsule button is
        // narrower than the list and hugs the row's right edge), top 6px below.
        let origin = NSPoint(
            x: anchor.maxX - size.width + shadowPad,
            y: anchor.minY - 6 - (size.height - shadowPad)
        )
        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
        self.panel = panel

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window != self?.panel {
                self?.close()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close(fireCallback: Bool = true) {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        if fireCallback { onClose?() }
    }
}
