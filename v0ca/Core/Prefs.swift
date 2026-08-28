import Foundation

/// All user preferences: UserDefaults keys + typed accessors.
enum Prefs {
    enum Key {
        static let translateToEnglish = "translateToEnglish"
        static let appendSpace = "appendSpace"
        static let insertMethod = "insertMethod"
        static let clipboardHandling = "clipboardHandling"
        static let autoSend = "autoSend"
        static let hudPosition = "hudPosition"
        static let hudOffset = "hudOffset"
        /// Keep a thin bar on screen at all times; hovering it opens the quick menu.
        static let hudAlwaysVisible = "hudAlwaysVisible"
        /// Selected mode in the quick menu. "Ask" and "Screen" are not wired up yet.
        static let hudMode = "hudMode"
        /// Provider models picked on the Providers tab, as "<provider>/<model>".
        /// The API keys themselves live in the Keychain, never here.
        static let askModel = "askModel"
        static let screenModel = "screenModel"
        static let soundStart = "soundStart"
        static let soundDone = "soundDone"
        static let historyLimit = "historyLimit"
        static let historyAutoDelete = "historyAutoDelete"
        /// Carbon hotkeys can't handle the fn key — recording is triggered via CGEventTap.
        static let toggleRecordingUsesFn = "toggleRecordingUsesFn"
        /// Onboarding finished (or skipped): the tab is hidden and doesn't open on launch.
        static let onboardingDone = "onboardingDone"
        /// App theme (the Appearance section). Stored only for now —
        /// the design system has no dark theme yet.
        static let appTheme = "appTheme"
        /// Accent color (hex without #). Stored only for now — Tokens.accent is static.
        static let accentColor = "accentColor"

        // The keys below are read by domain logic in their own modules (AppLanguage,
        // RecognitionLanguage, ModelManager…) — only the strings live here so that
        // all UserDefaults keys stay in one place. Never change the strings: that
        // would reset users' saved settings.
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

        /// Age limit for records; nil — the limit is not age-based.
        var maxAge: TimeInterval? {
            switch self {
            case .threeDays: 3 * 86_400
            case .twoWeeks: 14 * 86_400
            case .threeMonths: 90 * 86_400
            case .last5, .off: nil
            }
        }

        /// Count limit for records; nil — the limit is not count-based.
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

    /// Mode picked in the always-visible bar. Only `dictation` does anything so far —
    /// the other two are placeholders for the API-backed modes from the mockup.
    enum HUDMode: String, CaseIterable {
        case dictation
        case ask
        case screen

        var label: String {
            switch self {
            case .dictation: "Диктовка"
            case .ask: "Спросить"
            case .screen: "Экран"
            }
        }

        /// True for the modes that send anything over the network. Drives the
        /// violet accents: red must stay the colour of "this stays on device".
        var isRemote: Bool { self != .dictation }

        /// Where the audio and the text go — shown above the mode list.
        var route: String {
            switch self {
            case .dictation: "На устройстве · ничего не покидает Mac"
            case .ask: "Ваши проиндексированные заметки · ответ от модели по API"
            case .screen: "Весь экран уходит в модель по API"
            }
        }

        var icon: String {
            switch self {
            case .dictation: "mic"
            case .ask: "sparkles"
            case .screen: "display"
            }
        }
    }

    enum AppTheme: String, CaseIterable {
        case light
        case dark
        case system

        var label: String {
            switch self {
            case .light: "Светлая"
            case .dark: "Тёмная"
            case .system: "Системная"
            }
        }
    }

    enum InsertMethod: String, CaseIterable {
        case paste // clipboard + automatic ⌘V
        case type // synthetic character-by-character input, clipboard untouched
        case clipboardOnly // copy only

        var label: String {
            switch self {
            case .paste: "Через буфер (⌘V)"
            case .type: "Печатать без буфера"
            case .clipboardOnly: "Только буфер обмена"
            }
        }
    }

    enum ClipboardHandling: String, CaseIterable {
        /// "Keep unchanged" (default): after pasting, the clipboard is restored to its
        /// original state — the transcript doesn't stay in it.
        case unchanged = "restore"
        /// The transcript stays in the clipboard after pasting.
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
        case enter // press Enter after pasting

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

    /// Append a space after the inserted transcript (on by default).
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

    /// HUD offset from the screen edge (default "Small", 56px).
    static var hudOffset: HUDOffset {
        HUDOffset(rawValue: UserDefaults.standard.string(forKey: Key.hudOffset) ?? "") ?? .low
    }

    /// Sound when recording starts (on by default).
    static var soundStart: Bool {
        UserDefaults.standard.object(forKey: Key.soundStart) as? Bool ?? true
    }

    /// Completion sound (text is ready and inserted; on by default).
    static var soundDone: Bool {
        UserDefaults.standard.object(forKey: Key.soundDone) as? Bool ?? true
    }

    /// Maximum number of history records (default 200, as in the mockup).
    static var historyLimit: Int {
        UserDefaults.standard.object(forKey: Key.historyLimit) as? Int ?? 200
    }

    static var historyAutoDelete: HistoryAutoDelete {
        HistoryAutoDelete(rawValue: UserDefaults.standard.string(forKey: Key.historyAutoDelete) ?? "") ?? .twoWeeks
    }

    /// Use the fn key (🌐 Globe) as the recording trigger instead of a Carbon hotkey.
    static var toggleRecordingUsesFn: Bool {
        UserDefaults.standard.bool(forKey: Key.toggleRecordingUsesFn)
    }

    static var onboardingDone: Bool {
        UserDefaults.standard.bool(forKey: Key.onboardingDone)
    }

    static var hudAlwaysVisible: Bool {
        UserDefaults.standard.bool(forKey: Key.hudAlwaysVisible)
    }

    static var hudMode: HUDMode {
        HUDMode(rawValue: UserDefaults.standard.string(forKey: Key.hudMode) ?? "") ?? .dictation
    }
}
