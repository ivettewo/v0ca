import Observation

/// Active settings window tab — lets the window open straight on the right tab.
@MainActor
@Observable
final class SettingsRouter {
    var tab: SettingsRootView.Tab = .dictation
}
