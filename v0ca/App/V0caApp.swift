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
            // Until onboarding is done, recording is disabled and settings stay closed —
            // only the first-run setup window is available.
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
        // Debug rendering of onboarding screenshots — renders and quits the app.
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
        // First launch (no onboarding-done flag) — show only the onboarding
        // window: recording and settings stay unavailable until "Done" is pressed.
        if !Prefs.onboardingDone {
            onboardingWindow.show()
        }
    }

    /// Open the onboarding window (menu bar entry until setup is complete).
    func showOnboarding() {
        onboardingWindow.show()
    }

    /// App became active again — retry starting the fn monitor (Accessibility
    /// may have been granted in System Settings while we were away).
    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator.startFnMonitorIfNeeded()
    }

    /// Dock icon click — open settings (or onboarding while it's not finished).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Prefs.onboardingDone {
            settingsWindow.show()
        } else {
            onboardingWindow.show()
        }
        return true
    }
}
