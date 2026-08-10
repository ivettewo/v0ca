import Observation

/// Активная вкладка окна настроек — чтобы открывать окно сразу на нужной вкладке.
@MainActor
@Observable
final class SettingsRouter {
    var tab: SettingsRootView.Tab = .dictation
}
