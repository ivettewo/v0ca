import AppKit
import SwiftUI

/// Borderless-панель поверх всех окон, не забирает фокус у активного приложения —
/// иначе вставка текста через ⌘V попадёт не туда.
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

    /// По центру, 112px от ФИЗИЧЕСКОГО края экрана (как в макете: bottom 112px),
    /// а не от видимой области — иначе капсула висит выше Дока.
    func position() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let size = panel.frame.size
        // Капсула прижата к низу панели с отступом 4 — компенсируем его.
        let edgeOffset = Prefs.hudOffset.points
        let y: CGFloat = switch Prefs.hudPosition {
        case .bottom: frame.minY + edgeOffset - 4
        case .top: frame.maxY - edgeOffset - size.height + 4
        }
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: y))
    }
}
