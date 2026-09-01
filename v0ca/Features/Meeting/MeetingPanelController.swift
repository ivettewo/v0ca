import AppKit
import SwiftUI

/// The conversation panel: a floating window at the right edge of the screen,
/// up for as long as the call lasts.
///
/// Unlike the HUD, this one takes keyboard input — the title is editable and the
/// panel owns shortcuts — but it must not pull focus out of Zoom, so it is a
/// `.nonactivatingPanel` that can become key without activating the app.
///
/// Step 3 of docs/modules/MEETING-BUILD.md.
/// A borderless window refuses to become key by default, and then the title
/// can't be typed into. This one accepts keys without ever becoming main, so the
/// app stays in the background while the field works.
private final class MeetingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class MeetingPanelController {
    private let panel: MeetingPanel
    private let answerPanel: MeetingPanel
    private let coordinator: RecordingCoordinator
    private var answerWatcher: Task<Void, Never>?

    /// Geometry from the mockup: 372 wide, 16 clear of three edges, and the
    /// answer 340 × 452 beside it.
    private static let width: CGFloat = 372
    private static let inset: CGFloat = 16
    private static let answerSize = NSSize(width: 340, height: 452)

    init(coordinator: RecordingCoordinator) {
        self.coordinator = coordinator
        panel = MeetingPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        // Out of screen sharing: the other side must not watch their own words
        // being transcribed back at them.
        panel.sharingType = .none

        answerPanel = MeetingPanel(
            contentRect: NSRect(origin: .zero, size: Self.answerSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        for window in [panel, answerPanel] {
            window.isFloatingPanel = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.hidesOnDeactivate = false
            window.sharingType = .none
        }

        let answerHost = NSHostingView(rootView: MeetingAnswerView(coordinator: coordinator))
        answerHost.wantsLayer = true
        answerHost.layer?.backgroundColor = .clear
        answerPanel.contentView = answerHost

        let host = NSHostingView(rootView: MeetingPanelView(coordinator: coordinator))
        // Without this the layer keeps its opaque backing and the rounded
        // corners cut into black instead of the desktop.
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        panel.contentView = host

        // The answer window follows the answer itself: no separate command to
        // open or close it, it is simply there while there is something in it.
        answerWatcher = Task { [weak self] in
            while !Task.isCancelled {
                let wanted = coordinator.meetingAnswer.isVisible && (self?.isVisible ?? false)
                if wanted != (self?.answerPanel.isVisible ?? false) {
                    wanted == true ? self?.showAnswer() : self?.answerPanel.orderOut(nil)
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        position()
        panel.orderFrontRegardless()
        // Key, but not active: the title field takes typing while the call app
        // keeps the foreground.
        panel.makeKey()
    }

    func hide() {
        panel.orderOut(nil)
        answerPanel.orderOut(nil)
    }

    private func showAnswer() {
        let frame = panel.frame
        answerPanel.setFrame(
            NSRect(
                x: frame.minX - Self.answerSize.width - 8,
                y: frame.maxY - Self.answerSize.height,
                width: Self.answerSize.width,
                height: Self.answerSize.height
            ),
            display: true
        )
        answerPanel.orderFrontRegardless()
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Right edge of the screen with the cursor on it, clear of the menu bar and
    /// the Dock — `visibleFrame` already accounts for both.
    private func position() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrame(
            NSRect(
                x: frame.maxX - Self.width - Self.inset,
                y: frame.minY + Self.inset,
                width: Self.width,
                height: frame.height - Self.inset * 2
            ),
            display: true
        )
    }
}
