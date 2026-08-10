import AppKit
import Observation
import SwiftUI

/// Выбранный акцентный цвет (секция «Оформление»). @Observable — чтение в body
/// делает вью реактивными: смена цвета мгновенно перекрашивает интерфейс,
/// тем же механизмом, что смена языка (AppLanguage) и темы.
@Observable
final class AccentStore {
    static let shared = AccentStore()

    /// Hex базового цвета без # (из палитры GeneralTab).
    var hex: String {
        didSet { UserDefaults.standard.set(hex, forKey: Prefs.Key.accentColor) }
    }

    private init() {
        hex = UserDefaults.standard.string(forKey: Prefs.Key.accentColor) ?? "E03E3E"
    }
}

/// Семья акцентных цветов, сгенерированная от одного базового: hover/active/soft
/// строятся HSB-формулами, откалиброванными по эталонной красной семье
/// (сгенерированная красная совпадает с исторической вручную подобранной).
/// Каждый цвет — динамическая пара светлый/тёмный.
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

        // Базовый одинаков в обеих темах (как исторический Signal Red).
        base = Self.dyn(h, light: (s, b), dark: (s, b))
        // Ховер: в светлой чуть темнее, в тёмной — чуть светлее (текст на тёмном).
        hover = Self.dyn(h, light: (min(1, s * 1.04), b * 0.90), dark: (s * 0.88, min(1, b * 1.04)))
        active = Self.dyn(h, light: (min(1, s * 1.07), b * 0.75), dark: (s * 0.99, b * 0.93))
        // Soft: пастельный фон выделений; в тёмной — глубокий приглушённый.
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
