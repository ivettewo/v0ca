import SwiftUI

/// Наборы цветов градиентных шапок из макетов — единственный источник для
/// экранов онбординга и вкладок настроек (одни и те же тройки используются
/// и там и там). Тёмные варианты — те же оттенки, приглушённые и затемнённые
/// (тёмного макета нет, подобраны вручную).
enum HeaderGradient {
    struct Triple {
        let left: Color
        let center: Color
        let right: Color
    }

    /// Зелёно-голубой: интро онбординга, вкладка «Общие».
    static let intro = Triple(
        left: Tokens.dynamic(0xCFEFEA, 0x22403C),
        center: Tokens.dynamic(0xD6ECF7, 0x24384A),
        right: Tokens.dynamic(0xC9E9A8, 0x2F401F)
    )
    /// Розово-персиковый: интерстишл «Мощно и бесплатно».
    static let powerFree = Triple(
        left: Tokens.dynamic(0xF7DDE4, 0x402A31),
        center: Tokens.dynamic(0xFBE6D2, 0x403222),
        right: Tokens.dynamic(0xE6DCF7, 0x332A40)
    )
    /// Голубой: разрешения (онбординг и вкладка), вкладка «Звук».
    static let permissions = Triple(
        left: Tokens.dynamic(0xE6F1FD, 0x20304A),
        center: Tokens.dynamic(0xEDF5FE, 0x243448),
        right: Tokens.dynamic(0xDCEAFB, 0x1E2C40)
    )
    /// Сине-сиреневый: интерстишл выбора модели, вкладка «История».
    static let modelIntro = Triple(
        left: Tokens.dynamic(0xCFE7FA, 0x20344A),
        center: Tokens.dynamic(0xFBE3D6, 0x403020),
        right: Tokens.dynamic(0xE7D9F8, 0x302440)
    )
    /// Жёлто-персиковый: шорткаты (онбординг), вкладка «Диктовка».
    static let shortcuts = Triple(
        left: Tokens.dynamic(0xFDE8B8, 0x403618),
        center: Tokens.dynamic(0xF6E1C3, 0x3A2F1D),
        right: Tokens.dynamic(0xFFD3C2, 0x40261C)
    )
    /// Голубо-зелёный: финал онбординга.
    static let final = Triple(
        left: Tokens.dynamic(0x9FE3F7, 0x164050),
        center: Tokens.dynamic(0xB7D8FA, 0x1E3450),
        right: Tokens.dynamic(0xBFF0D8, 0x1C4030)
    )

    /// Линейный сине-серый каталога моделей (в макете hsla 212/218).
    static let modelsLinear = (
        start: Tokens.dynamic(0x6E91B9, 0x3A5578),
        end: Tokens.dynamic(0xBCC8DC, 0x333A48)
    )
}
