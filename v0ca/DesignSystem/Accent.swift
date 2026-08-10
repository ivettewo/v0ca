import AppKit
import Observation
import SwiftUI

/// The selected accent color (Appearance section). @Observable — reading it in body
/// makes views reactive: changing the color instantly recolors the UI,
/// via the same mechanism as language (AppLanguage) and theme switching.
@Observable
final class AccentStore {
    static let shared = AccentStore()

    /// Base color hex without # (from the GeneralTab palette).
    var hex: String {
        didSet { UserDefaults.standard.set(hex, forKey: Prefs.Key.accentColor) }
    }

    private init() {
        hex = UserDefaults.standard.string(forKey: Prefs.Key.accentColor) ?? "E03E3E"
    }
}

/// Accent color family generated from a single base color: hover/active/soft
/// are derived via HSB formulas calibrated against the reference red family
/// (the generated red matches the original hand-picked one).
/// Each color is a dynamic light/dark pair.
struct AccentFamily {
    let base: Color
    let hover: Color
    let active: Color
    let soft: Color
    let softHover: Color

    private static var cache: [String: AccentFamily] = [:]

    static func family(for hexString: String) -> AccentFamily {
        if let cached = cache[hexString] {
            return cached
        }
        let family = AccentFamily(hex: UInt32(hexString, radix: 16) ?? 0xE03E3E)
        cache[hexString] = family
        return family
    }

    private init(hex: UInt32) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        NSColor(hexValue: hex).usingColorSpace(.sRGB)?
            .getHue(&h, saturation: &s, brightness: &b, alpha: nil)

        // The base color is the same in both themes (like the original Signal Red).
        base = Self.dyn(h, light: (s, b), dark: (s, b))
        // Hover: slightly darker in light theme, slightly lighter in dark (text on dark).
        hover = Self.dyn(h, light: (min(1, s * 1.04), b * 0.90), dark: (s * 0.88, min(1, b * 1.04)))
        active = Self.dyn(h, light: (min(1, s * 1.07), b * 0.75), dark: (s * 0.99, b * 0.93))
        // Soft: pastel selection background; deep and muted in dark theme.
        soft = Self.dyn(h, light: (max(0.05, s * 0.09), 0.99), dark: (s * 0.55, 0.245))
        softHover = Self.dyn(h, light: (s * 0.35, 0.96), dark: (s * 0.6, 0.35))
    }

    private static func dyn(
        _ hue: CGFloat,
        light: (s: CGFloat, b: CGFloat),
        dark: (s: CGFloat, b: CGFloat)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let variant = appearance.isDark ? dark : light
            return NSColor(hue: hue, saturation: variant.s, brightness: variant.b, alpha: 1)
        })
    }
}
