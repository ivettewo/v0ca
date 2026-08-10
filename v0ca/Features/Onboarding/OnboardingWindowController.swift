import AppKit
import SwiftUI

/// Окно нового онбординга по макету «Онбординг · Финальные экраны»: 720×600,
/// фиксированный размер, свой тайтлбар (системный прозрачный, как в настройках).
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
            // При .fullSizeContentView контент-вью занимает весь фрейм окна,
            // включая тайтлбар: задаём итоговые 720×600 фреймом, а не contentRect,
            // иначе окно выходит на высоту тайтлбара выше макета.
            window.setFrame(NSRect(x: 0, y: 0, width: 720, height: 600), display: false)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
