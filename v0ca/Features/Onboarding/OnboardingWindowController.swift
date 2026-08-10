import AppKit
import SwiftUI

/// Window for the new onboarding per the "Onboarding · Final screens" mockup:
/// 720×600, fixed size, custom title bar (transparent system one, as in settings).
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private let models: ModelManager

    init(models: ModelManager) {
        self.models = models
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Настройка v0ca"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(Tokens.surface)
            window.contentView = NSHostingView(rootView: OnboardingView(models: models) { [weak self] in
                self?.window?.close()
            })
            // With .fullSizeContentView the content view fills the entire window
            // frame, title bar included: set the final 720×600 via the frame, not
            // contentRect — otherwise the window ends up taller than the mockup
            // by the title bar height.
            window.setFrame(NSRect(x: 0, y: 0, width: 720, height: 600), display: false)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
