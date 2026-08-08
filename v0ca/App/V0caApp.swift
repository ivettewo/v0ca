import SwiftUI

@main
struct V0caApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("v0ca", systemImage: menuBarSymbol) {
            MenuContent(appDelegate: appDelegate)
        }
    }

    private var menuBarSymbol: String {
        appDelegate.coordinator.state == .recording ? "mic.fill" : "mic"
    }
}

private struct MenuContent: View {
    let appDelegate: AppDelegate

    var body: some View {
        Button(appDelegate.coordinator.state == .recording ? L("Остановить запись") : L("Начать запись")) {
            appDelegate.coordinator.toggle()
        }
        if case .downloading(let percent) = appDelegate.coordinator.modelState {
            Text("\(L("Загрузка модели…")) \(percent)%")
        }
        Divider()
        Button(L("Настройки…")) {
            appDelegate.settingsWindow.show()
        }
        Divider()
        Button(L("Выйти из v0ca")) {
            NSApp.terminate(nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = RecordingCoordinator(models: ModelManager(), history: HistoryStore())
    private(set) lazy var settingsWindow = SettingsWindowController(coordinator: coordinator)
    private var hud: HUDPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hud = HUDPanelController(coordinator: coordinator)
        coordinator.onMicDenied = { [weak self] in
            self?.settingsWindow.show(tab: .permissions)
        }
        // Первый запуск — открываем настройки на онбординге; после его завершения
        // сюда больше не попадаем (ключ в UserDefaults).
        if !Prefs.onboardingDone {
            settingsWindow.show(tab: .onboarding)
        }
    }

    /// Возврат в приложение — повторно пробуем поднять fn-монитор (Accessibility
    /// могли выдать в системных настройках, пока нас не было).
    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator.startFnMonitorIfNeeded()
    }

    /// Клик по иконке в Доке — открыть настройки.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }
}
