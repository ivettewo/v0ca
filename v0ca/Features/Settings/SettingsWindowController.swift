import AppKit
import SwiftUI

/// Окно настроек: открывается из меню-бара и по клику на иконку в Доке.
/// Топ-бар рисуется внутри SettingsRootView, системный тайтлбар прозрачный.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let coordinator: RecordingCoordinator
    private let router = SettingsRouter()
    /// Открыть окно нового онбординга — назначается в AppDelegate до первого show().
    var openOnboarding: () -> Void = {}

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
                openOnboarding: openOnboarding,
                router: router
            ))
            // При .fullSizeContentView контент-вью занимает весь фрейм окна —
            // задаём итоговые 960×640 фреймом (как у окна онбординга).
            window.setFrame(NSRect(x: 0, y: 0, width: 960, height: 640), display: false)
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
