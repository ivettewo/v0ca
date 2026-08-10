import AppKit
import SwiftUI

/// Вкладка «История» по макету «Настройки · Новые экраны», вкладка 04:
/// сверху карточка настроек (автоудаление + папка), ниже записи, сгруппированные
/// по дням (Сегодня / Вчера / дата) в табличном виде: время слева, текст,
/// действия справа — появляются только при наведении на строку. Воспроизведение
/// без прогресс-бара: клик по play сразу играет запись.
struct HistoryTab: View {
    let coordinator: RecordingCoordinator

    @AppStorage(Prefs.Key.historyLimit) private var historyLimit: Int = 200
    @AppStorage(Prefs.Key.historyAutoDelete) private var autoDelete: String = Prefs.HistoryAutoDelete.twoWeeks.rawValue
    @FocusState private var sizeFocused: Bool

    @State private var playback = PlaybackController()

    private var store: HistoryStore { coordinator.history }

    var body: some View {
        // LazyVStack: при большой истории строятся только видимые карточки дней,
        // иначе сотня строк лейаутится разом и скролл лагает.
        LazyVStack(alignment: .leading, spacing: 22) {
            settingsCard

            if store.records.isEmpty {
                Text(L("Записей пока нет — продиктуйте что-нибудь."))
                    .font(Tokens.sans(12))
                    .foregroundStyle(Tokens.text3)
            } else {
                ForEach(groupedByDay, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(dayLabel(group.day))
                        HistoryRecordsCard(coordinator: coordinator, records: group.records, playback: playback)
                    }
                }
            }
        }
    }

    // MARK: - Настройки (карточка без заголовка, по макету)

    private var settingsCard: some View {
        VStack(spacing: 0) {
            SettingRow(
                title: L("Размер истории"),
                subtitle: L("Сколько записей хранить — остальные удаляются автоматически")
            ) {
                TextField("", value: $historyLimit, format: .number)
                    .textFieldStyle(.plain)
                    .font(Tokens.mono(13))
                    .multilineTextAlignment(.center)
                    .focused($sizeFocused)
                    .frame(width: 56)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .dsFieldStyle(focused: sizeFocused, radius: 18)
                    .textCursor()
                    .unfocusOnOutsideClick($sizeFocused)
                    .onChange(of: historyLimit) { store.enforceLimits() }
            }
            RowDivider()
            SettingRow(
                title: L("Автоматическое удаление записей"),
                subtitle: L("Старые записи удаляются, чтобы не занимать место")
            ) {
                DesignDropdown(
                    options: Prefs.HistoryAutoDelete.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $autoDelete,
                    width: 180
                )
                .onChange(of: autoDelete) { store.enforceLimits() }
            }
            RowDivider()
            SettingRow(title: L("Папка с записями")) {
                OnboardingPillButton(L("Открыть"), action: {
                    NSWorkspace.shared.open(HistoryStore.recordingsFolder)
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: Tokens.radiusCard).stroke(Tokens.cardBorder, lineWidth: 1))
        .onDisappear { playback.stop() }
    }

    // MARK: - Группировка по дням

    private var groupedByDay: [(day: Date, records: [HistoryRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: store.records) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { day in
            (day: day, records: groups[day] ?? [])
        }
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return L("Сегодня") }
        if calendar.isDateInYesterday(day) { return L("Вчера") }
        return Self.dayFormatter.string(from: day)
    }

    /// «15 июля» — локаль следует за языком интерфейса (SectionLabel сам капсит).
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: AppLanguage.shared.code == .ru ? "ru_RU" : "en_US")
        return formatter
    }()

}
