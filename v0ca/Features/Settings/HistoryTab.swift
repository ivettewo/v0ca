import AppKit
import SwiftUI

/// "History" tab per the "Settings · New screens" mockup, tab 04:
/// settings card on top (auto-delete + folder), records below, grouped
/// by day (Today / Yesterday / date) in tabular form: time on the left, text,
/// actions on the right — shown only when hovering a row. Playback has
/// no progress bar: clicking play plays the record right away.
struct HistoryTab: View {
    let coordinator: RecordingCoordinator

    @AppStorage(Prefs.Key.historyLimit) private var historyLimit: Int = 200
    @AppStorage(Prefs.Key.historyAutoDelete) private var autoDelete: String = Prefs.HistoryAutoDelete.twoWeeks.rawValue
    @FocusState private var sizeFocused: Bool

    @State private var playback = PlaybackController()
    @State private var filter: Filter = .all

    /// One timeline for everything; the filter only hides rows.
    private enum Filter: Hashable, CaseIterable {
        case all, dictation, ask, screen

        var label: String {
            switch self {
            case .all: "Всё"
            case .dictation: "Диктовка"
            case .ask: "Спросить"
            case .screen: "Экран"
            }
        }

        func matches(_ record: HistoryRecord) -> Bool {
            switch self {
            case .all: true
            case .dictation: record.kind == .dictation
            case .ask: record.kind == .ask
            case .screen: record.kind == .screen
            }
        }
    }

    private var visibleRecords: [HistoryRecord] {
        store.records.filter { filter.matches($0) }
    }

    private var store: HistoryStore { coordinator.history }

    var body: some View {
        // LazyVStack: with a large history only visible day cards are built,
        // otherwise a hundred rows lay out at once and scrolling stutters.
        LazyVStack(alignment: .leading, spacing: 22) {
            settingsCard

            // Only worth showing once there is something to sort through.
            if store.records.contains(where: { $0.kind != .dictation }) {
                DSSegmentedControl(
                    options: Filter.allCases.map { (value: $0, label: L($0.label)) },
                    selection: $filter
                )
            }

            if visibleRecords.isEmpty {
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

    // MARK: - Settings (untitled card, per the mockup)

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

    // MARK: - Grouping by day

    private var groupedByDay: [(day: Date, records: [HistoryRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: visibleRecords) { calendar.startOfDay(for: $0.date) }
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

    /// "15 июля" — locale follows the UI language (SectionLabel handles uppercasing).
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: AppLanguage.shared.code == .ru ? "ru_RU" : "en_US")
        return formatter
    }()

}
