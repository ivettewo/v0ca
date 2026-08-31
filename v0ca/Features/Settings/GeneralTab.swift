import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    let coordinator: RecordingCoordinator

    @AppStorage(Prefs.Key.recognitionLanguage) private var recognitionLanguage: String = "auto"
    @AppStorage(Prefs.Key.pushToTalk) private var pushToTalk: Bool = false
    @AppStorage(Prefs.Key.doublePressLatch) private var doublePressLatch = false
    @AppStorage(Prefs.Key.unloadModelAfterMinutes) private var unloadAfterMinutes: Int = 15
    @AppStorage(Prefs.Key.translateToEnglish) private var translateToEnglish: Bool = false
    @AppStorage(Prefs.Key.appendSpace) private var appendSpace: Bool = true
    @AppStorage(Prefs.Key.insertMethod) private var insertMethod: String = Prefs.InsertMethod.paste.rawValue
    @AppStorage(Prefs.Key.clipboardHandling) private var clipboardHandling: String = Prefs.ClipboardHandling.unchanged.rawValue
    @AppStorage(Prefs.Key.autoSend) private var autoSend: String = Prefs.AutoSend.off.rawValue
    @AppStorage(Prefs.Key.hudPosition) private var hudPosition: String = Prefs.HUDPosition.bottom.rawValue
    @AppStorage(Prefs.Key.hudOffset) private var hudOffset: String = Prefs.HUDOffset.low.rawValue
    @AppStorage(Prefs.Key.hudAlwaysVisible) private var hudAlwaysVisible = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Bindable private var language = AppLanguage.shared
    @AppStorage(Prefs.Key.appTheme) private var appTheme: String = Prefs.AppTheme.light.rawValue
    /// Accent goes through AccentStore: recolors the UI immediately.
    @State private var accentStore = AccentStore.shared

    /// Accent palette: five from the mockup + emerald and light blue.
    private static let accentOptions = [
        "E03E3E", "D9823E", "5FA173", "3AA68B", "55A9CE", "5B84C0", "9C74C4",
    ]

    /// Only multilingual Whisper can translate — otherwise the toggle is disabled.
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
            SettingRow(
                title: L("Двойное нажатие — запись без удержания"),
                subtitle: pushToTalk
                    ? L("Два быстрых нажатия оставляют запись включённой, следующее — останавливает")
                    : L("Работает в режиме «Нажми и говори»")
            ) {
                AccentToggle(isOn: $doublePressLatch, enabled: pushToTalk)
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
            ForEach(Prefs.HUDMode.allCases, id: \.self) { mode in
                RowDivider()
                SettingRow(
                    title: L("Режим «%@»", L(mode.label)),
                    subtitle: hudAlwaysVisible ? nil : L("Работает, когда включена полоска")
                ) {
                    ShortcutField(name: .mode(mode))
                }
            }
        }

        SettingsSection(title: L("Система")) {
            SettingRow(title: L("Язык интерфейса")) {
                // Labels are language endonyms, not translated.
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
            SettingRow(
                title: L("Всегда показывать полоску"),
                subtitle: L("Тонкая полоска у края экрана; наведите на неё — откроется быстрое меню")
            ) {
                AccentToggle(isOn: $hudAlwaysVisible)
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

        SettingsSection(title: L("Оформление")) {
            SettingRow(title: L("Тема")) {
                DSSegmentedControl(
                    options: Prefs.AppTheme.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $appTheme
                )
                .onChange(of: appTheme) { Theme.apply() }
            }
            RowDivider()
            SettingRow(title: L("Акцентный цвет")) {
                HStack(spacing: 12) {
                    ForEach(Self.accentOptions, id: \.self) { hex in
                        accentDot(hex)
                    }
                }
            }
        }
    }

    /// 22px accent dot; the selected one gets a white gap and an outer colored ring.
    private func accentDot(_ hex: String) -> some View {
        let color = Color(hex: UInt32(hex, radix: 16) ?? 0xE03E3E)
        return Button {
            accentStore.hex = hex
        } label: {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay {
                    if accentStore.hex == hex {
                        Circle().stroke(Tokens.surface, lineWidth: 2).padding(-1)
                        Circle().stroke(color, lineWidth: 1.5).padding(-2.75)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}
