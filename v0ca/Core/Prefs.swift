import Foundation

/// Все пользовательские настройки: ключи UserDefaults + типизированный доступ.
enum Prefs {
    enum Key {
        static let translateToEnglish = "translateToEnglish"
        static let appendSpace = "appendSpace"
        static let insertMethod = "insertMethod"
        static let clipboardHandling = "clipboardHandling"
        static let autoSend = "autoSend"
        static let hudPosition = "hudPosition"
        static let hudOffset = "hudOffset"
        static let soundStart = "soundStart"
        static let soundDone = "soundDone"
        static let historyLimit = "historyLimit"
        static let historyAutoDelete = "historyAutoDelete"
        /// Клавиша ⌥/Carbon-хоткей не умеет fn — запись триггерится через CGEventTap.
        static let toggleRecordingUsesFn = "toggleRecordingUsesFn"
        /// Онбординг завершён (или пропущен): вкладка скрыта и при запуске не открывается.
        static let onboardingDone = "onboardingDone"

        // Ключи ниже читаются доменной логикой в своих модулях (AppLanguage,
        // RecognitionLanguage, ModelManager…) — здесь только строки, чтобы все
        // ключи UserDefaults жили в одном месте. Строки менять нельзя: это
        // сбросит сохранённые настройки пользователей.
        static let interfaceLanguage = "interfaceLanguage"
        static let recognitionLanguage = "recognitionLanguage"
        static let inputDeviceUID = "inputDeviceUID"
        static let activeModelID = "activeModelID"
        static let pushToTalk = "pushToTalk"
        static let unloadModelAfterMinutes = "unloadModelAfterMinutes"
    }

    enum HistoryAutoDelete: String, CaseIterable {
        case last5
        case threeDays
        case twoWeeks
        case threeMonths
        case off

        /// Ограничение по возрасту записи; nil — ограничение не по возрасту.
        var maxAge: TimeInterval? {
            switch self {
            case .threeDays: 3 * 86_400
            case .twoWeeks: 14 * 86_400
            case .threeMonths: 90 * 86_400
            case .last5, .off: nil
            }
        }

        /// Ограничение по количеству записей; nil — ограничение не по количеству.
        var maxCount: Int? {
            switch self {
            case .last5: 5
            case .threeDays, .twoWeeks, .threeMonths, .off: nil
            }
        }

        var label: String {
            switch self {
            case .last5: "Последние 5"
            case .threeDays: "Через 3 дня"
            case .twoWeeks: "Через 2 недели"
            case .threeMonths: "Через 3 месяца"
            case .off: "Никогда"
            }
        }
    }

    enum InsertMethod: String, CaseIterable {
        case paste // буфер + автоматический ⌘V
        case type // синтетический ввод посимвольно, буфер не трогается
        case clipboardOnly // только скопировать

        var label: String {
            switch self {
            case .paste: "Через буфер (⌘V)"
            case .type: "Печатать без буфера"
            case .clipboardOnly: "Только буфер обмена"
            }
        }
    }

    enum ClipboardHandling: String, CaseIterable {
        /// «Не изменять» (по умолчанию): после вставки буфер возвращается в исходное
        /// состояние — транскрипт в нём не остаётся.
        case unchanged = "restore"
        /// Транскрипт остаётся в буфере после вставки.
        case keepTranscript = "keep"

        var label: String {
            switch self {
            case .unchanged: "Не изменять"
            case .keepTranscript: "Оставлять транскрипт в буфере"
            }
        }
    }

    enum AutoSend: String, CaseIterable {
        case off
        case enter // нажать Enter после вставки

        var label: String {
            switch self {
            case .off: "Выключено"
            case .enter: "Enter после вставки"
            }
        }
    }

    enum HUDPosition: String, CaseIterable {
        case bottom
        case top

        var label: String {
            switch self {
            case .bottom: "Снизу экрана"
            case .top: "Сверху экрана"
            }
        }
    }

    enum HUDOffset: String, CaseIterable {
        case edge
        case low
        case medium
        case high

        var points: CGFloat {
            switch self {
            case .edge: 24
            case .low: 56
            case .medium: 112
            case .high: 180
            }
        }

        var label: String {
            switch self {
            case .edge: "Вплотную к краю"
            case .low: "Небольшой"
            case .medium: "Средний"
            case .high: "Большой"
            }
        }
    }

    static var translateToEnglish: Bool {
        UserDefaults.standard.bool(forKey: Key.translateToEnglish)
    }

    /// Пробел после вставленной транскрибации (по умолчанию включено).
    static var appendSpace: Bool {
        UserDefaults.standard.object(forKey: Key.appendSpace) as? Bool ?? true
    }

    static var insertMethod: InsertMethod {
        InsertMethod(rawValue: UserDefaults.standard.string(forKey: Key.insertMethod) ?? "") ?? .paste
    }

    static var clipboardHandling: ClipboardHandling {
        ClipboardHandling(rawValue: UserDefaults.standard.string(forKey: Key.clipboardHandling) ?? "") ?? .unchanged
    }

    static var autoSend: AutoSend {
        AutoSend(rawValue: UserDefaults.standard.string(forKey: Key.autoSend) ?? "") ?? .off
    }

    static var hudPosition: HUDPosition {
        HUDPosition(rawValue: UserDefaults.standard.string(forKey: Key.hudPosition) ?? "") ?? .bottom
    }

    /// Отступ HUD от края экрана (по умолчанию «Небольшой», 56px).
    static var hudOffset: HUDOffset {
        HUDOffset(rawValue: UserDefaults.standard.string(forKey: Key.hudOffset) ?? "") ?? .low
    }

    /// Звук начала записи (по умолчанию включён).
    static var soundStart: Bool {
        UserDefaults.standard.object(forKey: Key.soundStart) as? Bool ?? true
    }

    /// Звук завершения (текст готов и вставлен; по умолчанию включён).
    static var soundDone: Bool {
        UserDefaults.standard.object(forKey: Key.soundDone) as? Bool ?? true
    }

    /// Максимум записей истории (по умолчанию 200, как в макете).
    static var historyLimit: Int {
        UserDefaults.standard.object(forKey: Key.historyLimit) as? Int ?? 200
    }

    static var historyAutoDelete: HistoryAutoDelete {
        HistoryAutoDelete(rawValue: UserDefaults.standard.string(forKey: Key.historyAutoDelete) ?? "") ?? .twoWeeks
    }

    /// Использовать клавишу fn (🌐 Globe) как триггер записи вместо Carbon-хоткея.
    static var toggleRecordingUsesFn: Bool {
        UserDefaults.standard.bool(forKey: Key.toggleRecordingUsesFn)
    }

    static var onboardingDone: Bool {
        UserDefaults.standard.bool(forKey: Key.onboardingDone)
    }
}
