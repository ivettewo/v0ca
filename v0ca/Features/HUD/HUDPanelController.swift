import AppKit
import SwiftUI

/// Borderless panel above all windows; never steals focus from the active app —
/// otherwise the ⌘V paste would land in the wrong place.
///
/// The panel has three sizes, and the current one doubles as the hover zone.
/// While the resting bar just sits there the panel is only as big as the bar, so
/// the rest of the screen bottom stays clickable and the cursor has to actually
/// reach the bar; it then grows to fit a capsule, and again for the open mode menu.
@MainActor
final class HUDPanelController {
    private let panel: NSPanel
    private let coordinator: RecordingCoordinator
    private let bar = HUDBarState()
    private var collapseTask: Task<Void, Never>?
    private var hoverTask: Task<Void, Never>?

    /// How long the cursor has to rest on the bar before it opens.
    private static let hoverDelay: Duration = .milliseconds(300)

    /// Enough room for the Ask bubble with its answer and buttons, and no more:
    /// the bubble now stays up while you keep working, and every point of panel
    /// above it is a point of screen that silently eats clicks.
    /// Six lines of text (161) + footer (46) + capsule (46) + room for the shadow,
    /// plus the screenshot thumbnail in the "Screen" flow.
    private static let askSize = NSSize(width: 460, height: 360)
    /// Enough room for the quick menu with the mode list open.
    private static let menuSize = NSSize(width: 380, height: 300)
    /// Room for a capsule — quick menu, recording, transcribing. Also the hover
    /// zone once the bar has grown, so it matches the 280 × 60 from the mockup.
    private static let capsuleSize = NSSize(width: 280, height: 64)
    /// The resting bar is 72 × 6; the hover zone is the bar plus a little slack,
    /// which is all that ever intercepts clicks while idle.
    private static let barSize = NSSize(width: 96, height: 26)

    init(coordinator: RecordingCoordinator) {
        self.coordinator = coordinator
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.menuSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        // The hosting view sits inside a tracking host: SwiftUI has no hover
        // that works while the app is inactive, and the panel never becomes key.
        let hover = HUDHoverView(frame: NSRect(origin: .zero, size: Self.menuSize))
        hover.autoresizingMask = [.width, .height]
        let host = NSHostingView(rootView: HUDView(coordinator: coordinator, bar: bar))
        host.frame = hover.bounds
        host.autoresizingMask = [.width, .height]
        hover.addSubview(host)
        panel.contentView = hover

        hover.onHover = { [weak self] inside in
            self?.hoverChanged(inside)
        }
        bar.onExpandedChange = { [weak self] in
            self?.applyLayout()
        }
        coordinator.ask.onPhaseChange = { [weak self] in
            self?.applyLayout()
        }
        coordinator.stateDidChange = { [weak self] _ in
            self?.applyLayout()
        }
        // The bar can be switched on and off in Settings while the app runs.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyLayout() }
        }

        applyLayout()
        panel.orderFrontRegardless()
    }

    // MARK: - Hover

    /// Never cancel a pending collapse here: leaving the panel fires more than one
    /// exit, and the follow-up ones are no-ops for the state — cancelling on them
    /// used to strand the panel at full size, turning the whole rect into a hover zone.
    ///
    /// Opening waits out `hoverDelay`: the bar sits where the cursor crosses on its
    /// way somewhere else, and popping the menu open on every fly-by is noise.
    /// Closing is immediate — once you have left, you have left.
    private func hoverChanged(_ inside: Bool) {
        hoverTask?.cancel()
        guard inside else {
            bar.setHovered(false)
            return
        }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hoverDelay)
            guard !Task.isCancelled else { return }
            self?.bar.setHovered(true)
        }
    }

    // MARK: - Layout

    /// How much room the panel needs right now. Everything else follows from this.
    ///
    /// Hovering already claims the full menu size even though the menu is closed.
    /// Growing on open instead looks broken: the panel resize and the SwiftUI
    /// layout land in different frames, so for a moment the menu is laid out
    /// inside a 64pt panel, overflows it and gets clipped by the window — which
    /// reads as the bar jumping. With the room reserved up front, opening the
    /// menu changes nothing about the window at all.
    private var targetSize: NSSize {
        // The room is claimed the moment an Ask recording starts, not when the
        // bubble appears: growing the panel after the fact leaves the bubble laid
        // out inside a capsule-sized window for a frame, and it visibly jumps.
        if coordinator.ask.isActive || (isAskFlow && coordinator.state != .hidden) {
            return Self.askSize
        }
        if bar.expanded {
            return Self.menuSize
        }
        if coordinator.state != .hidden {
            return Self.capsuleSize
        }
        return Prefs.hudAlwaysVisible ? Self.barSize : Self.capsuleSize
    }

    /// A press that will end in a bubble rather than in pasted text — a spoken
    /// question or a screenshot. Both need the room reserved before the bubble
    /// exists, or it gets laid out inside a capsule-sized window for a frame.
    private var isAskFlow: Bool {
        Prefs.hudAlwaysVisible && Prefs.hudMode.isRemote
    }

    private func applyLayout() {
        let alwaysVisible = Prefs.hudAlwaysVisible
        if !alwaysVisible, coordinator.state == .hidden {
            bar.reset()
        }
        // Clicks pass through unless there is something to click: the recording
        // capsule, the quick menu, or the resting bar waiting to be hovered.
        panel.ignoresMouseEvents = coordinator.state == .hidden
            && !alwaysVisible && !coordinator.ask.isActive

        let target = targetSize
        guard panel.frame.size != target else {
            position()
            return
        }
        collapseTask?.cancel()
        if target.height >= panel.frame.height {
            resize(to: target)
        } else {
            // Let the capsule finish collapsing before the panel clips it away.
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(480))
                guard !Task.isCancelled, let self else { return }
                let target = self.targetSize
                guard self.panel.frame.size != target else { return }
                self.resize(to: target)
            }
        }
    }

    private func resize(to size: NSSize) {
        panel.setContentSize(size)
        position()
    }

    /// Centered on the main display (the one with the menu bar), a set distance
    /// from the PHYSICAL screen edge — not from the visible area, otherwise the
    /// capsule hangs above the Dock.
    func position() {
        guard let screen = NSScreen.screens.first else { return }
        let frame = screen.frame
        let size = panel.frame.size
        // The capsule is pinned to the panel bottom with a 4pt inset — compensate for it.
        let edgeOffset = Prefs.hudOffset.points
        let y: CGFloat = switch Prefs.hudPosition {
        case .bottom: frame.minY + edgeOffset - 4
        case .top: frame.maxY - edgeOffset - size.height + 4
        }
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: y))
    }
}
