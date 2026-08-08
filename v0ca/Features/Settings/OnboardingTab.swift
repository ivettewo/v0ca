import KeyboardShortcuts
import SwiftUI

/// Вкладка «Онбординг» — три шага до первой диктовки. Открывается автоматически
/// при первом запуске; после «Завершить» (или «Пропустить») ключ пишется в
/// UserDefaults, вкладка пропадает из сайдбара и больше не открывается.
///
/// Шаги не «проходятся» кнопкой «Далее» — их статус определяется реальным
/// состоянием системы (разрешения выданы, модель на диске, комбинация задана),
/// поэтому галочки загораются сами, в любом порядке.
struct OnboardingTab: View {
    let models: ModelManager
    let router: SettingsRouter

    @AppStorage(Prefs.Key.onboardingDone) private var onboardingDone = false
    @State private var permissionsGranted = false
    @State private var shortcutSet = false

    /// Разрешения и хоткей меняются вне SwiftUI (системные настройки, UserDefaults) —
    /// перечитываем раз в секунду, как на вкладке «Разрешения».
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var modelReady: Bool {
        models.itemStates.values.contains(.downloaded)
    }

    private var allDone: Bool { permissionsGranted && modelReady && shortcutSet }

    var body: some View {
        SettingsSection(title: L("Быстрый старт")) {
            step(
                1,
                done: permissionsGranted,
                title: L("Выдать разрешения"),
                subtitle: L("Микрофон — чтобы записывать голос, Универсальный доступ — чтобы вставлять текст")
            ) {
                if !permissionsGranted {
                    DSButton(L("Перейти"), compact: true) { router.tab = .permissions }
                }
            }
            RowDivider()
            step(
                2,
                done: modelReady,
                title: L("Скачать модель"),
                subtitle: L("Подойдёт любая из раздела «Рекомендуем» — дождись конца загрузки")
            ) {
                if !modelReady {
                    DSButton(L("Перейти"), compact: true) { router.tab = .models }
                }
            }
            RowDivider()
            step(
                3,
                done: shortcutSet,
                title: L("Назначить комбинацию записи"),
                subtitle: L("Нажми на поле и зажми сочетание — можно просто fn")
            ) {
                ShortcutField(name: .toggleRecording, fnPrefKey: Prefs.Key.toggleRecordingUsesFn)
            }
        }

        HStack(spacing: 14) {
            if allDone {
                DSButton(L("Завершить онбординг"), variant: .primary) { finish() }
            } else {
                DSButton(L("Пропустить"), variant: .ghost) { finish() }
            }
            Text(L("Шаги можно пройти в любом порядке — после завершения вкладка исчезнет."))
                .font(Tokens.sans(11.5))
                .foregroundStyle(Tokens.text3)
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private func refresh() {
        permissionsGranted = PermissionsTab.allGranted
        shortcutSet = KeyboardShortcuts.getShortcut(for: .toggleRecording) != nil
            || Prefs.toggleRecordingUsesFn
    }

    private func finish() {
        onboardingDone = true
        router.tab = .general
    }

    // MARK: - Строка шага

    private func step(
        _ number: Int,
        done: Bool,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 13) {
            badge(number, done: done)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.sans(13.5))
                    .foregroundStyle(Tokens.text)
                Text(subtitle)
                    .font(Tokens.sans(11.5))
                    .foregroundStyle(Tokens.text3)
            }
            Spacer(minLength: 16)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Кружок слева: номер шага, после выполнения — зелёный с галочкой.
    private func badge(_ number: Int, done: Bool) -> some View {
        ZStack {
            if done {
                Circle().fill(Tokens.success)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Tokens.border, lineWidth: 1.5)
                Text("\(number)")
                    .font(Tokens.mono(11, weight: .medium))
                    .foregroundStyle(Tokens.text2)
            }
        }
        .frame(width: 22, height: 22)
        .animation(.easeInOut(duration: 0.18), value: done)
    }
}
