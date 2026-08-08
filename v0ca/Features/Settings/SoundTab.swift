import SwiftUI

struct SoundTab: View {
    @AppStorage(AudioDevices.selectedUIDKey) private var selectedMicUID: String = ""
    @AppStorage(Prefs.Key.soundStart) private var soundStart: Bool = true
    @AppStorage(Prefs.Key.soundDone) private var soundDone: Bool = true
    @State private var devices: [AudioInputDevice] = []
    @State private var tester = MicLevelTester()

    var body: some View {
        SettingsSection(title: L("Выбор микрофона")) {
            SettingRow(title: L("Устройство")) {
                DesignDropdown(
                    options: [(value: "", label: L("Системный по умолчанию"))]
                        + devices.map { (value: $0.uid, label: $0.name) },
                    selection: $selectedMicUID,
                    width: 240
                )
            }
            RowDivider()
            SettingRow(title: L("Уровень"), subtitle: levelSubtitle) {
                HStack(spacing: 10) {
                    levelMeter
                    DSButton(tester.isRunning ? L("Стоп") : L("Проверить"), compact: true) {
                        if tester.isRunning {
                            tester.stop()
                        } else {
                            tester.start()
                        }
                    }
                }
            }
            if let error = tester.errorText {
                Text(error)
                    .font(Tokens.sans(11.5))
                    .foregroundStyle(Tokens.accent)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        SettingsSection(title: L("Звук")) {
            SettingRow(title: L("Звук начала записи")) {
                AccentToggle(isOn: $soundStart)
            }
            RowDivider()
            SettingRow(title: L("Звук завершения"), subtitle: L("Когда текст готов и вставлен")) {
                AccentToggle(isOn: $soundDone)
            }
        }

        .onAppear {
            devices = AudioDevices.inputDevices()
        }
        .onDisappear {
            tester.stop()
        }
        .onChange(of: selectedMicUID) {
            if tester.isRunning {
                tester.restart()
            }
        }
    }

    private var levelSubtitle: String? {
        tester.isRunning ? L("Скажите что-нибудь — индикатор должен двигаться.") : nil
    }

    private var levelMeter: some View {
        DSProgressBar(
            fraction: CGFloat(min(tester.level, 1)),
            height: 6,
            fill: AnyShapeStyle(LinearGradient(
                colors: [Tokens.success, Color(hex: 0xB4C94A), Tokens.processing],
                startPoint: .leading,
                endPoint: .trailing
            ))
        )
        .frame(width: 160)
        .animation(.linear(duration: 0.08), value: tester.level)
    }
}
