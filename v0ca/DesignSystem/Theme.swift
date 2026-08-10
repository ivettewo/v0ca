import AppKit

/// Applies the appearance theme: tokens are dynamic NSColors, so all this has
/// to do is set the app's appearance. "System" (nil) follows macOS,
/// including live switching.
enum Theme {
    static func apply() {
        let saved = Prefs.AppTheme(
            rawValue: UserDefaults.standard.string(forKey: Prefs.Key.appTheme) ?? ""
        ) ?? .light
        NSApp.appearance = switch saved {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}
