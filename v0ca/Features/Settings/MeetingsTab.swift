import SwiftUI

/// "Meetings" tab per the meeting-panel mockup, screen 7: the calls that were
/// recorded, and the knobs the panel obeys. Behind the meeting module — no
/// module, no tab.
///
/// Step 5 of docs/modules/MEETING-BUILD.md.
struct MeetingsTab: View {
    let coordinator: RecordingCoordinator

    private enum Section: Hashable {
        case history
        case settings

        var label: String {
            switch self {
            case .history: "История"
            case .settings: "Настройки"
            }
        }
    }

    @State private var section: Section = .history
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @AppStorage(Prefs.Key.meetingProfile) private var profile = Prefs.MeetingProfile.meeting.rawValue
    @AppStorage(Prefs.Key.meetingThreshold) private var threshold = 0.006
    @AppStorage(Prefs.Key.meetingWindowSeconds) private var window = 3.0
    @AppStorage(Prefs.Key.meetingAutoAnswer) private var autoAnswer = false
    @AppStorage(Prefs.Key.meetingConfidence) private var confidence = 0.5

    private var conversations: [HistoryRecord] {
        let all = coordinator.history.records.filter { $0.kind == .meeting }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { $0.text.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            switch section {
            case .history: history
            case .settings: settings
            }
        }
    }

    /// Title on the left, the two sections as a pill on the right — the mockup
    /// keeps the switcher out of the content flow.
    private var header: some View {
        HStack(spacing: 12) {
            Text(L("Митинги"))
                .font(Tokens.sans(20, weight: .semibold))
                .kerning(-0.2)
                .foregroundStyle(Tokens.text)
            Spacer(minLength: 16)
            DSSegmentedControl(
                options: [Section.history, .settings].map { (value: $0, label: L($0.label)) },
                selection: $section
            )
        }
        .padding(.leading, 4)
    }

    // MARK: - History

    @ViewBuilder
    private var history: some View {
        StatsMetricsCard(rows: [[
            StatsMetric(caption: L("Митингов"), value: "\(allConversations.count)"),
            StatsMetric(caption: L("Часов записано"), value: StatsFormat.hours(totalSeconds)),
            StatsMetric(caption: L("Реплик"), value: StatsFormat.compact(totalLines)),
            StatsMetric(caption: L("Последний"), value: lastLabel),
        ]])

        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                SectionLabel(L("Разговоры"))
                Spacer(minLength: 16)
                searchField
            }

            if conversations.isEmpty {
                Text(allConversations.isEmpty
                    ? L("Разговоров пока нет — начните первый в панели.")
                    : L("Ничего не нашлось."))
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(Tokens.text3)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(conversations.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            RowDivider()
                        }
                        row(record)
                    }
                }
                .padding(.horizontal, 20)
                .dsCard()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.text3)
            TextField(L("Поиск по разговорам"), text: $search)
                .textFieldStyle(.plain)
                .font(Tokens.sans(13))
                .foregroundStyle(Tokens.text)
                .focused($searchFocused)
        }
        .padding(.horizontal, 14)
        .frame(width: 220, height: 36)
        .dsFieldStyle(focused: searchFocused, radius: 18)
        .textCursor()
    }

    /// Time on the left, name and what was said in the middle, per the mockup.
    /// The summary line is the opening of the conversation: a real summary needs
    /// a model, and that is a later step.
    private func row(_ record: HistoryRecord) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(Self.time(of: record))
                .font(Tokens.mono(11.5, weight: .medium))
                .foregroundStyle(Tokens.text3)
                .frame(width: 48, alignment: .leading)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(Self.title(of: record))
                        .font(Tokens.sans(14, weight: .medium))
                        .foregroundStyle(Tokens.text)
                        .lineLimit(1)
                    Text(L("%@ · %@ реплик", record.durationLabel, "\(Self.lineCount(record))"))
                        .font(Tokens.sans(12))
                        .foregroundStyle(Tokens.text3)
                        .lineLimit(1)
                }
                Text(Self.preview(of: record))
                    .font(Tokens.sans(13.5))
                    .lineSpacing(4)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
        }
        .padding(.vertical, 13)
    }

    // MARK: - Settings

    @ViewBuilder
    private var settings: some View {
        SettingsSection(title: L("Режим разговора")) {
            SettingRow(
                title: L("Профиль"),
                subtitle: L(Prefs.MeetingProfile(rawValue: profile)?.hint ?? "")
            ) {
                DSSegmentedControl(
                    options: Prefs.MeetingProfile.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $profile
                )
                .onChange(of: profile) { _, picked in
                    guard let values = Prefs.MeetingProfile(rawValue: picked)?.values else { return }
                    threshold = values.threshold
                    window = values.window
                }
            }
            RowDivider()
            SettingRow(title: L("Порог срабатывания")) {
                meter($threshold, range: 0.002...0.02, format: { String(format: "%.3f", $0) })
            }
            RowDivider()
            SettingRow(title: L("Окно нарезки реплик")) {
                meter($window, range: 1.5...8, format: { String(format: "%.1f с", $0) })
            }
        }

        SettingsSection(title: L("Вопросы")) {
            SettingRow(
                title: L("Порог уверенности"),
                subtitle: L("Ниже этого панель промолчит — ложная отметка мешает больше, чем пропущенный вопрос")
            ) {
                meter($confidence, range: 0.3...0.9, format: { String(format: "%.2f", $0) }, marksCustom: false)
            }
            RowDivider()
            SettingRow(
                title: L("Автоответ на вопросы"),
                subtitle: L("Ответ приходит сам, без нажатия — окно откроется прямо во время разговора")
            ) {
                AccentToggle(isOn: $autoAnswer)
            }
        }

        SettingsSection(title: L("Клавиши в панели")) {
            SettingRow(title: L("Ответить на вопрос"), subtitle: L("Работает, пока панель в фокусе")) {
                Text("⌘↵")
                    .font(Tokens.mono(12.5, weight: .medium))
                    .foregroundStyle(Tokens.textMeta)
            }
            RowDivider()
            SettingRow(title: L("Скопировать вопрос")) {
                Text("⌘C")
                    .font(Tokens.mono(12.5, weight: .medium))
                    .foregroundStyle(Tokens.textMeta)
            }
        }

        Text(L("Значения применяются к следующему разговору: менять их посреди звонка — значит двигать границу между репликами."))
            .font(Tokens.sans(12))
            .lineSpacing(3)
            .foregroundStyle(Tokens.text3)
            .padding(.horizontal, 4)
    }

    /// Slider drawn as the mockup's thin track with the value beside it.
    ///
    /// "Custom" is chosen by *dragging*, not by the value changing: a preset sets
    /// both numbers itself, and watching the value would have the preset
    /// immediately un-select itself.
    private func meter(
        _ value: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String,
        marksCustom: Bool = true
    ) -> some View {
        HStack(spacing: 18) {
            Slider(value: value, in: range) { editing in
                if editing, marksCustom {
                    profile = Prefs.MeetingProfile.custom.rawValue
                }
            }
                .controlSize(.small)
                .frame(width: 200)
                .tint(Tokens.text)
            Text(format(value.wrappedValue))
                .font(Tokens.mono(12.5, weight: .medium))
                .foregroundStyle(Tokens.text)
                .frame(width: 56, alignment: .trailing)
        }
    }

    // MARK: - Values

    private var allConversations: [HistoryRecord] {
        coordinator.history.records.filter { $0.kind == .meeting }
    }

    private var totalSeconds: Double {
        allConversations.reduce(0) { $0 + $1.duration }
    }

    private var totalLines: Int {
        allConversations.reduce(0) { $0 + Self.lineCount($1) }
    }

    private var lastLabel: String {
        guard let last = allConversations.first else { return "—" }
        return Self.time(of: last)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static func time(of record: HistoryRecord) -> String {
        timeFormatter.string(from: record.date)
    }

    /// A named conversation put its title on the first line; an unnamed one has
    /// only speech there, and then the date has to stand in for a name.
    private static func title(of record: HistoryRecord) -> String {
        let first = String(record.text.split(separator: "\n", maxSplits: 1).first ?? "")
        let spoken = first.hasPrefix("Я: ") || first.hasPrefix("Собеседник: ")
        return spoken ? record.dateLabel : first
    }

    private static func preview(of record: HistoryRecord) -> String {
        let lines = record.text.split(separator: "\n").map(String.init)
        let body = lines.first.map { $0.hasPrefix("Я: ") || $0.hasPrefix("Собеседник: ") }
            == true ? lines : Array(lines.dropFirst())
        return body.prefix(2).joined(separator: " ")
    }

    private static func lineCount(_ record: HistoryRecord) -> Int {
        record.text.split(separator: "\n").count
    }
}
