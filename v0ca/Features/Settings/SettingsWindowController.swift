import AppKit
import SwiftUI

/// Settings window: opened from the menu bar and by clicking the Dock icon.
/// The top bar is drawn inside SettingsRootView; the system title bar is transparent.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let coordinator: RecordingCoordinator
    private let router = SettingsRouter()

    init(coordinator: RecordingCoordinator) {
        self.coordinator = coordinator
    }

    func show(tab: SettingsRootView.Tab? = nil) {
        if let tab {
            router.tab = tab
        }
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Настройки"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(Tokens.background)
            window.contentView = NSHostingView(rootView: SettingsRootView(
                coordinator: coordinator,
                router: router
            ))
            // With .fullSizeContentView the content view fills the whole window frame —
            // set the final 960×640 via the frame (same as the onboarding window).
            window.setFrame(NSRect(x: 0, y: 0, width: 960, height: 640), display: false)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
