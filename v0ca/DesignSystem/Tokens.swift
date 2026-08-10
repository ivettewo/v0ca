import AppKit
import CoreText
import SwiftUI

/// v0ca design system tokens — see docs/DESIGN.md.
/// All colors are dynamic light/dark pairs (NSColor dynamicProvider):
/// AppKit resolves them against the current appearance; theme switching is Theme.apply().
/// The dark palette was picked by hand (there is no dark mockup).
enum Tokens {
    /// Brand Signal Red: the dot in "v0ca." is always red, independent of the accent.
    static let brand = Color(hex: 0xE03E3E)

    // Accent — a family derived from the color chosen in Appearance (AccentStore);
    // computed: reading them in body makes views react to accent changes.
    static var accent: Color { family.base }
    /// Accent button hover and "red text" (lighter, not darker, in dark theme).
    static var accentHover: Color { family.hover }
    static var accentActive: Color { family.active }
    /// Soft accent: danger-soft button background, field focus ring (accent100).
    static var accentSoft: Color { family.soft }
    /// Danger-soft button hover (accent300).
    static var accentSoftHover: Color { family.softHover }

    private static var family: AccentFamily {
        AccentFamily.family(for: AccentStore.shared.hex)
    }

    // Semantics
    static let processing = Color(hex: 0xE8A13C)
    static let success = Color(hex: 0x3EAF6E)
    /// "Granted" badge background (onboarding).
    static let successSoft = dynamic(0xE3F4EA, 0x1F3A2C)
    /// Text on successSoft.
    static let successDeep = dynamic(0x2C7A4E, 0x6ED397)

    // Surfaces and text
    static let background = dynamic(0xF4F4F6, 0x202024)
    static let surface = dynamic(0xFFFFFF, 0x2A2A2F)
    static let surface2 = dynamic(0xEFEFF1, 0x3A3A41)
    /// Slightly tinted surface: window title bars, model catalog cards.
    static let surfaceSoft = dynamic(0xFAFAFB, 0x303036)
    /// Row background on hover (history, dictation).
    static let surfaceHover = dynamic(0xF7F7F9, 0x33333A)
    /// Raised element on surface2 (active segment of the segmented control).
    static let raised = dynamic(0xFFFFFF, 0x4A4A53)
    static let border = dynamic(0xE3E3E7, 0x3C3C43)
    /// Border of white section cards (softer than border) — "Settings · New screens" mockup.
    static let cardBorder = dynamic(0xE7E7EB, 0x3A3A41)
    /// Border of pill controls: dropdowns, shortcut fields.
    static let controlBorder = dynamic(0xDDDDE2, 0x47474F)
    /// Control border on hover and the unselected radio circle.
    static let controlBorderHover = dynamic(0xC9C9CF, 0x5A5A64)
    /// Barely visible outline of decorative mockups.
    static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.08) : NSColor(white: 0, alpha: 0.06)
    })
    static let text = dynamic(0x1B1B1F, 0xF2F2F4)
    static let text2 = dynamic(0x6C6C74, 0xA6A6AE)
    static let text3 = dynamic(0x9B9BA3, 0x73737C)
    /// Emphasized small metadata text (model languages/size).
    static let textMeta = dynamic(0x4A4A52, 0xC8C8CE)
    /// Text and icons on accent fills (buttons, download bar).
    static let textOnAccent = Color.white
    /// Toggle knob.
    static let knob = Color.white

    // Decoration
    /// Skeleton lines in onboarding mockups.
    static let skeleton = dynamic(0xEDEDF0, 0x3C3C42)
    /// Bottom ledge of keycaps.
    static let keycapLedge = dynamic(0xD6D6DC, 0x1B1B1E)
    /// Middle color of the mic level scale (between success and processing).
    static let levelMid = Color(hex: 0xB4C94A)

    // Shadows (base colors; opacity is set at the call sites)
    static let shadowCard = dynamic(0x283C6E, 0x000000)
    static let shadowHUD = dynamic(0x182030, 0x000000)

    /// Dynamic light/dark pair: AppKit picks the variant for the current
    /// appearance at draw time. Also available to HeaderGradients.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hexValue: appearance.isDark ? dark : light)
        })
    }

    // Radii
    static let radiusControl: CGFloat = 8
    /// Section cards: 18 per the "Settings · New screens" mockup (was 12).
    static let radiusCard: CGFloat = 18
    static let radiusWindow: CGFloat = 14

    /// Monospaced: logo, timers, hotkeys, dates. SF Mono is a system font;
    /// no monospaced fonts are bundled at all.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// UI text — bundled Google Sans (as in the mockups);
    /// falls back to system SF Pro if the files are missing.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard googleSansRegistered else {
            return .system(size: size, weight: weight)
        }
        let name = switch weight {
        case .semibold, .bold: "GoogleSans-SemiBold"
        case .medium: "GoogleSans-Medium"
        default: "GoogleSans-Regular"
        }
        return .custom(name, size: size)
    }

    /// The "v0ca." logo — Atkinson Hyperlegible Mono ("Settings · New screens"
    /// mockup), falling back to the system mono.
    static func logo(_ size: CGFloat) -> Font {
        guard logoRegistered else { return mono(size, weight: .semibold) }
        return .custom("AtkinsonHyperlegibleMono-SemiBold", size: size)
    }

    /// Registers the TTFs from Resources/Fonts once on first access.
    private static let googleSansRegistered: Bool = {
        register(["GoogleSans-Regular", "GoogleSans-Medium", "GoogleSans-SemiBold"])
    }()

    private static let logoRegistered: Bool = {
        register(["AtkinsonHyperlegibleMono-SemiBold"])
    }()

    private static func register(_ names: [String]) -> Bool {
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                return false
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension NSColor {
    convenience init(hexValue: UInt32) {
        self.init(
            srgbRed: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
