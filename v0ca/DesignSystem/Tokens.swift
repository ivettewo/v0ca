import AppKit
import CoreText
import SwiftUI

/// Токены дизайн-системы v0ca — см. docs/DESIGN.md.
/// Все цвета — динамические пары светлый/тёмный (NSColor dynamicProvider):
/// AppKit резолвит их под текущую appearance, переключение темы — Theme.apply().
/// Тёмная палитра подобрана вручную (тёмного макета нет).
enum Tokens {
    /// Фирменный Signal Red: точка в «v0ca.» — всегда красная, акценту не подчиняется.
    static let brand = Color(hex: 0xE03E3E)

    // Акцент — семья от выбранного в «Оформлении» цвета (AccentStore),
    // вычисляемые: чтение в body делает вью реактивными к смене акцента.
    static var accent: Color { family.base }
    /// Ховер акцентных кнопок и «красный текст» (в тёмной — светлее, не темнее).
    static var accentHover: Color { family.hover }
    static var accentActive: Color { family.active }
    /// Мягкий акцент: фон danger-soft кнопок, фокус-ринг полей (accent100).
    static var accentSoft: Color { family.soft }
    /// Ховер danger-soft кнопок (accent300).
    static var accentSoftHover: Color { family.softHover }

    private static var family: AccentFamily {
        AccentFamily.family(for: AccentStore.shared.hex)
    }

    // Семантика
    static let processing = Color(hex: 0xE8A13C)
    static let success = Color(hex: 0x3EAF6E)
    /// Фон бейджа «Разрешено» (онбординг).
    static let successSoft = dynamic(0xE3F4EA, 0x1F3A2C)
    /// Текст на successSoft.
    static let successDeep = dynamic(0x2C7A4E, 0x6ED397)

    // Поверхности и текст
    static let background = dynamic(0xF4F4F6, 0x202024)
    static let surface = dynamic(0xFFFFFF, 0x2A2A2F)
    static let surface2 = dynamic(0xEFEFF1, 0x3A3A41)
    /// Слегка тонированная поверхность: тайтлбар окон, карточки каталога моделей.
    static let surfaceSoft = dynamic(0xFAFAFB, 0x303036)
    /// Фон строки при наведении (история, диктовка).
    static let surfaceHover = dynamic(0xF7F7F9, 0x33333A)
    /// Приподнятый элемент на surface2 (активный сегмент переключателя).
    static let raised = dynamic(0xFFFFFF, 0x4A4A53)
    static let border = dynamic(0xE3E3E7, 0x3C3C43)
    /// Рамка белых карточек секций (мягче border) — макет «Настройки · Новые экраны».
    static let cardBorder = dynamic(0xE7E7EB, 0x3A3A41)
    /// Рамка контролов-пилюль: дропдауны, поля шорткатов.
    static let controlBorder = dynamic(0xDDDDE2, 0x47474F)
    /// Рамка контролов при ховере и радио-кружок без выбора.
    static let controlBorderHover = dynamic(0xC9C9CF, 0x5A5A64)
    /// Едва заметная обводка декоративных мокапов.
    static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.08) : NSColor(white: 0, alpha: 0.06)
    })
    static let text = dynamic(0x1B1B1F, 0xF2F2F4)
    static let text2 = dynamic(0x6C6C74, 0xA6A6AE)
    static let text3 = dynamic(0x9B9BA3, 0x73737C)
    /// Усиленный мелкий текст метаданных (языки/размер модели).
    static let textMeta = dynamic(0x4A4A52, 0xC8C8CE)
    /// Текст и иконки на акцентных заливках (кнопки, полоса загрузки).
    static let textOnAccent = Color.white
    /// Ручка тумблера.
    static let knob = Color.white

    // Декор
    /// Скелетоны-строки в мокапах онбординга.
    static let skeleton = dynamic(0xEDEDF0, 0x3C3C42)
    /// Нижняя кромка клавиш-капов.
    static let keycapLedge = dynamic(0xD6D6DC, 0x1B1B1E)
    /// Средний цвет шкалы уровня микрофона (между success и processing).
    static let levelMid = Color(hex: 0xB4C94A)

    // Тени (цветовая база; прозрачность у мест применения)
    static let shadowCard = dynamic(0x283C6E, 0x000000)
    static let shadowHUD = dynamic(0x182030, 0x000000)

    /// Динамическая пара светлый/тёмный: AppKit выбирает вариант под appearance
    /// в момент отрисовки. Доступен и HeaderGradients.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hexValue: appearance.isDark ? dark : light)
        })
    }

    // Радиусы
    static let radiusControl: CGFloat = 8
    /// Карточки секций: 18 по макету «Настройки · Новые экраны» (было 12).
    static let radiusCard: CGFloat = 18
    static let radiusWindow: CGFloat = 14

    /// Моноширинный: логотип, таймеры, хоткеи, даты. SF Mono — системный,
    /// в бандле шрифтов нет вообще.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Интерфейсный текст — Google Sans из бандла (как в макетах);
    /// если файлы не нашлись — системный SF Pro.
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

    /// Логотип «v0ca.» — Atkinson Hyperlegible Mono (макет «Настройки · Новые
    /// экраны»), с фолбэком на системный mono.
    static func logo(_ size: CGFloat) -> Font {
        guard logoRegistered else { return mono(size, weight: .semibold) }
        return .custom("AtkinsonHyperlegibleMono-SemiBold", size: size)
    }

    /// Регистрируем TTF из Resources/Fonts один раз при первом обращении.
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
