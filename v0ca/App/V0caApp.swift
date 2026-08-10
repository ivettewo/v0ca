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

    @AppStorage(Prefs.Key.onboardingDone) private var onboardingDone = false

    var body: some View {
        if onboardingDone {
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
        } else {
            // До завершения онбординга запись выключена и настройки не открываем —
            // только окно настройки первого запуска.
            Button(L("Продолжить настройку…")) {
                appDelegate.showOnboarding()
            }
        }
        Divider()
        Button(L("Выйти из v0ca")) {
            NSApp.terminate(nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = RecordingCoordinator(
        models: ModelManager(),
        history: HistoryStore(),
        stats: StatsStore()
    )
    private(set) lazy var settingsWindow = SettingsWindowController(coordinator: coordinator)
    private lazy var onboardingWindow = OnboardingWindowController(models: coordinator.models)
    private var hud: HUDPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Отладочный рендер скриншотов онбординга — рендерит и завершает приложение.
        if OnboardingScreenshots.runIfRequested(models: coordinator.models) {
            return
        }
        Theme.apply()
        hud = HUDPanelController(coordinator: coordinator)
        settingsWindow.openOnboarding = { [weak self] in
            self?.onboardingWindow.show()
        }
        coordinator.onMicDenied = { [weak self] in
            self?.settingsWindow.show(tab: .permissions)
        }
        // Первый запуск (метки о пройденном онбординге нет) — только окно
        // онбординга: запись и настройки недоступны, пока не нажата «Готово».
        if !Prefs.onboardingDone {
            onboardingWindow.show()
        }
    }

    /// Открыть окно онбординга (меню-бар до завершения настройки).
    func showOnboarding() {
        onboardingWindow.show()
    }

    /// Возврат в приложение — повторно пробуем поднять fn-монитор (Accessibility
    /// могли выдать в системных настройках, пока нас не было).
    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator.startFnMonitorIfNeeded()
    }

    /// Клик по иконке в Доке — открыть настройки (или онбординг, пока не пройден).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Prefs.onboardingDone {
            settingsWindow.show()
        } else {
            onboardingWindow.show()
        }
        return true
    }
}
