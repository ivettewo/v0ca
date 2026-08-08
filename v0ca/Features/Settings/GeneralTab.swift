import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    let coordinator: RecordingCoordinator

    @AppStorage(Prefs.Key.recognitionLanguage) private var recognitionLanguage: String = "auto"
    @AppStorage(Prefs.Key.pushToTalk) private var pushToTalk: Bool = false
    @AppStorage(Prefs.Key.unloadModelAfterMinutes) private var unloadAfterMinutes: Int = 15
    @AppStorage(Prefs.Key.translateToEnglish) private var translateToEnglish: Bool = false
    @AppStorage(Prefs.Key.appendSpace) private var appendSpace: Bool = true
    @AppStorage(Prefs.Key.insertMethod) private var insertMethod: String = Prefs.InsertMethod.paste.rawValue
    @AppStorage(Prefs.Key.clipboardHandling) private var clipboardHandling: String = Prefs.ClipboardHandling.unchanged.rawValue
    @AppStorage(Prefs.Key.autoSend) private var autoSend: String = Prefs.AutoSend.off.rawValue
    @AppStorage(Prefs.Key.hudPosition) private var hudPosition: String = Prefs.HUDPosition.bottom.rawValue
    @AppStorage(Prefs.Key.hudOffset) private var hudOffset: String = Prefs.HUDOffset.low.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Bindable private var language = AppLanguage.shared

    /// Перевод умеет только мультиязычный Whisper — иначе тумблер неактивен.
    private var canTranslate: Bool {
        coordinator.models.activeModel?.canTranslateToEnglish ?? false
    }

    private static let languages: [(code: String, name: String)] = [
        ("auto", "Автоопределение"),
        ("ru", "Русский"),
        ("en", "Английский"),
        ("uk", "Украинский"),
        ("de", "Немецкий"),
        ("fr", "Французский"),
        ("es", "Испанский"),
        ("pt", "Португальский"),
        ("it", "Итальянский"),
    ]

    private static let unloadOptions: [(minutes: Int, name: String)] = [
        (0, "Никогда"),
        (5, "Через 5 минут"),
        (10, "Через 10 минут"),
        (15, "Через 15 минут"),
        (30, "Через 30 минут"),
        (60, "Через 1 час"),
        (120, "Через 2 часа"),
    ]

    var body: some View {
        SettingsSection(title: L("Запись")) {
            SettingRow(title: L("Нажми и говори"), subtitle: L("Запись идёт, пока клавиша удерживается")) {
                AccentToggle(isOn: $pushToTalk)
            }
            RowDivider()
            SettingRow(title: L("Язык распознавания")) {
                DesignDropdown(
                    options: Self.languages.map { (value: $0.code, label: L($0.name)) },
                    selection: $recognitionLanguage
                )
            }
            RowDivider()
            SettingRow(
                title: L("Переводить речь на английский автоматически"),
                subtitle: canTranslate
                    ? L("Речь на любом языке распознаётся сразу английским текстом")
                    : L("Активная модель не умеет переводить — выбери Whisper без пометки Turbo")
            ) {
                AccentToggle(isOn: $translateToEnglish, enabled: canTranslate)
            }
            RowDivider()
            SettingRow(title: L("Добавлять пробел"), subtitle: L("Пробел после вставленной транскрибации")) {
                AccentToggle(isOn: $appendSpace)
            }
        }

        SettingsSection(title: L("Вывод")) {
            SettingRow(title: L("Метод вставки")) {
                DesignDropdown(
                    options: Prefs.InsertMethod.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $insertMethod,
                    width: 220
                )
            }
            RowDivider()
            SettingRow(title: L("Обработка буфера обмена")) {
                DesignDropdown(
                    options: Prefs.ClipboardHandling.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $clipboardHandling,
                    width: 220
                )
            }
            RowDivider()
            SettingRow(title: L("Автоматическая отправка")) {
                DesignDropdown(
                    options: Prefs.AutoSend.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $autoSend,
                    width: 220
                )
            }
        }

        SettingsSection(title: L("Комбинации")) {
            SettingRow(title: L("Начать / остановить запись")) {
                ShortcutField(name: .toggleRecording, fnPrefKey: Prefs.Key.toggleRecordingUsesFn)
            }
            RowDivider()
            SettingRow(title: L("Отменить запись")) {
                ShortcutField(name: .cancelRecording)
            }
        }

        SettingsSection(title: L("Система")) {
            SettingRow(title: L("Язык интерфейса")) {
                // Подписи — самоназвания языков, не переводятся.
                DSSegmentedControl(
                    options: AppLanguage.Code.allCases.map { (value: $0, label: $0.label) },
                    selection: $language.code
                )
            }
            RowDivider()
            SettingRow(title: L("Запуск при старте системы")) {
                AccentToggle(isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            RowDivider()
            SettingRow(title: L("Положение индикатора записи")) {
                DesignDropdown(
                    options: Prefs.HUDPosition.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $hudPosition
                )
            }
            RowDivider()
            SettingRow(title: L("Отступ от края экрана")) {
                DesignDropdown(
                    options: Prefs.HUDOffset.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $hudOffset
                )
            }
            RowDivider()
            SettingRow(
                title: L("Выгружать модель"),
                subtitle: L("Освобождать память, если модель не используется указанное время")
            ) {
                DesignDropdown(
                    options: Self.unloadOptions.map { (value: $0.minutes, label: L($0.name)) },
                    selection: $unloadAfterMinutes
                )
            }
        }
    }
}
