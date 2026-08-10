import AppKit

/// Применение темы оформления: токены — динамические NSColor, поэтому вся
/// работа сводится к установке appearance приложения. «Системная» (nil)
/// следует за macOS, включая живое переключение.
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
