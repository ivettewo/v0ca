import SwiftUI

/// Gradient header color sets from the mockups — the single source for
/// onboarding screens and settings tabs (the same triples are used in both).
/// Dark variants are the same hues, muted and darkened
/// (there is no dark mockup; picked by hand).
enum HeaderGradient {
    struct Triple {
        let left: Color
        let center: Color
        let right: Color
    }

    /// Green-cyan: onboarding intro, General tab.
    static let intro = Triple(
        left: Tokens.dynamic(0xCFEFEA, 0x22403C),
        center: Tokens.dynamic(0xD6ECF7, 0x24384A),
        right: Tokens.dynamic(0xC9E9A8, 0x2F401F)
    )
    /// Pink-peach: the "Powerful and free" interstitial.
    static let powerFree = Triple(
        left: Tokens.dynamic(0xF7DDE4, 0x402A31),
        center: Tokens.dynamic(0xFBE6D2, 0x403222),
        right: Tokens.dynamic(0xE6DCF7, 0x332A40)
    )
    /// Blue: permissions (onboarding and tab), Sound tab.
    static let permissions = Triple(
        left: Tokens.dynamic(0xE6F1FD, 0x20304A),
        center: Tokens.dynamic(0xEDF5FE, 0x243448),
        right: Tokens.dynamic(0xDCEAFB, 0x1E2C40)
    )
    /// Blue-lilac: model selection interstitial, History tab.
    static let modelIntro = Triple(
        left: Tokens.dynamic(0xCFE7FA, 0x20344A),
        center: Tokens.dynamic(0xFBE3D6, 0x403020),
        right: Tokens.dynamic(0xE7D9F8, 0x302440)
    )
    /// Yellow-peach: shortcuts (onboarding), Dictation tab.
    static let shortcuts = Triple(
        left: Tokens.dynamic(0xFDE8B8, 0x403618),
        center: Tokens.dynamic(0xF6E1C3, 0x3A2F1D),
        right: Tokens.dynamic(0xFFD3C2, 0x40261C)
    )
    /// Cyan-blue: Providers tab ("New screens · Providers" mockup).
    static let providers = Triple(
        left: Tokens.dynamic(0xB6DDF0, 0x1C3A4C),
        center: Tokens.dynamic(0xC4DCF0, 0x22364C),
        right: Tokens.dynamic(0xD2D9EE, 0x282F44)
    )
    /// Green-yellow: Stats tab ("New screens · 05 Stats" mockup).
    static let stats = Triple(
        left: Tokens.dynamic(0xE8F0E2, 0x28361F),
        center: Tokens.dynamic(0xF4F0DC, 0x333520),
        right: Tokens.dynamic(0xFDE8B8, 0x403618)
    )
    /// Cyan-green: onboarding finale.
    static let final = Triple(
        left: Tokens.dynamic(0x9FE3F7, 0x164050),
        center: Tokens.dynamic(0xB7D8FA, 0x1E3450),
        right: Tokens.dynamic(0xBFF0D8, 0x1C4030)
    )

    /// Linear blue-gray for the model catalog (hsla 212/218 in the mockup).
    static let modelsLinear = (
        start: Tokens.dynamic(0x6E91B9, 0x3A5578),
        end: Tokens.dynamic(0xBCC8DC, 0x333A48)
    )
}
