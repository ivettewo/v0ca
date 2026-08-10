import AppKit
import SwiftUI

/// Borderless panel above all windows; never steals focus from the active app —
/// otherwise the ⌘V paste would land in the wrong place.
@MainActor
final class HUDPanelController {
    private let panel: NSPanel

    init(coordinator: RecordingCoordinator) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 96),
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
        panel.contentView = NSHostingView(rootView: HUDView(coordinator: coordinator))

        coordinator.stateDidChange = { [weak self] state in
            self?.panel.ignoresMouseEvents = (state == .hidden)
            self?.position()
        }

        position()
        panel.orderFrontRegardless()
    }

    /// Centered, 112px from the PHYSICAL screen edge (as in the mockup: bottom 112px),
    /// not from the visible area — otherwise the capsule hangs above the Dock.
    func position() {
        guard let screen = NSScreen.main else { return }
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
