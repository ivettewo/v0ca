import SwiftUI

/// Токены дизайн-системы v0ca — см. docs/DESIGN.md.
enum Tokens {
    // Акцент (Signal Red)
    static let accent = Color(hex: 0xE03E3E)
    static let accentHover = Color(hex: 0xC93232)
    static let accentActive = Color(hex: 0xA82626)
    /// Мягкий акцент: фон danger-soft кнопок, фокус-ринг полей (accent100).
    static let accentSoft = Color(hex: 0xFCEBEB)
    /// Ховер danger-soft кнопок (accent300).
    static let accentSoftHover = Color(hex: 0xF5B8B8)

    // Семантика
    static let processing = Color(hex: 0xE8A13C)
    static let success = Color(hex: 0x3EAF6E)

    // Светлая тема
    static let background = Color(hex: 0xF6F6F7)
    static let surface = Color(hex: 0xFFFFFF)
    static let surface2 = Color(hex: 0xEFEFF1)
    static let border = Color(hex: 0xE3E3E7)
    static let text = Color(hex: 0x1B1B1F)
    static let text2 = Color(hex: 0x6C6C74)
    static let text3 = Color(hex: 0x9B9BA3)

    // Радиусы
    static let radiusControl: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let radiusWindow: CGFloat = 14

    /// Моноширинный: логотип, таймеры, хоткеи, даты. SF Mono — системный,
    /// в бандле шрифтов нет вообще.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Интерфейсный текст — системный SF Pro.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
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
