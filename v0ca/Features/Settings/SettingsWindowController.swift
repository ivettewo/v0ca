import AppKit
import SwiftUI

/// Окно настроек: открывается из меню-бара и по клику на иконку в Доке.
/// Топ-бар рисуется внутри SettingsRootView, системный тайтлбар прозрачный.
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
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Настройки"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(srgbRed: 0xF6 / 255.0, green: 0xF6 / 255.0, blue: 0xF7 / 255.0, alpha: 1)
            window.contentView = NSHostingView(rootView: SettingsRootView(coordinator: coordinator, router: router))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
