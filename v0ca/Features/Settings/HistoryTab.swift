import AppKit
import SwiftUI

/// Вкладка «История» — по макету: плоские строки настроек + карточки записей
/// с датой моно, действиями, текстом и плеером.
struct HistoryTab: View {
    let coordinator: RecordingCoordinator

    @AppStorage(Prefs.Key.historyLimit) private var historyLimit: Int = 200
    @AppStorage(Prefs.Key.historyAutoDelete) private var autoDelete: String = Prefs.HistoryAutoDelete.twoWeeks.rawValue

    @State private var playback = PlaybackController()
    @State private var retranscribingID: UUID?
    @FocusState private var sizeFocused: Bool

    private var store: HistoryStore { coordinator.history }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(L("НАСТРОЙКИ"))
                .padding(.bottom, 4)

            settingRow(title: L("Размер истории"), subtitle: nil) {
                TextField("", value: $historyLimit, format: .number)
                    .textFieldStyle(.plain)
                    .font(Tokens.mono(13))
                    .multilineTextAlignment(.trailing)
                    .focused($sizeFocused)
                    .frame(width: 56)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .dsFieldStyle(focused: sizeFocused)
                    .onChange(of: historyLimit) { store.enforceLimits() }
                    .onReceive(NotificationCenter.default.publisher(for: .dismissFieldFocus)) { _ in
                        sizeFocused = false
                    }
            }
            Divider().overlay(Tokens.surface2)

            settingRow(
                title: L("Автоматическое удаление записей"),
                subtitle: L("Сколько записей хранить — остальные удаляются автоматически")
            ) {
                DesignDropdown(
                    options: Prefs.HistoryAutoDelete.allCases.map { (value: $0.rawValue, label: L($0.label)) },
                    selection: $autoDelete,
                    width: 180
                )
                .onChange(of: autoDelete) { store.enforceLimits() }
            }
            Divider().overlay(Tokens.surface2)

            settingRow(title: L("Папка с записями"), subtitle: nil) {
                DSButton(variant: .secondary, compact: true) {
                    NSWorkspace.shared.open(HistoryStore.recordingsFolder)
                } label: {
                    Label(L("Открыть в Finder"), systemImage: "folder")
                }
            }

            SectionLabel(L("ЗАПИСИ"))
                .padding(.top, 22)
                .padding(.bottom, 10)
                .overlay(alignment: .top) { Divider().overlay(Tokens.surface2) }

            if store.records.isEmpty {
                Text(L("Записей пока нет — продиктуйте что-нибудь."))
                    .font(Tokens.sans(12))
                    .foregroundStyle(Tokens.text3)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.records) { record in
                        recordCard(record)
                    }
                }
            }
        }
        .onDisappear {
            playback.stop()
        }
    }

    // MARK: - Карточка записи

    private func recordCard(_ record: HistoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(record.dateLabel)
                    .font(Tokens.mono(11, weight: .medium))
                    .foregroundStyle(Tokens.text3)
                Spacer()
                DSIconAction("doc.on.doc", help: L("Скопировать")) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(record.text, forType: .string)
                }
                DSIconAction(
                    record.favorite ? "star.fill" : "star",
                    help: L("В избранное"),
                    tint: record.favorite ? Tokens.processing : Tokens.text2
                ) {
                    store.toggleFavorite(record.id)
                }
                if retranscribingID == record.id {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    DSIconAction("arrow.clockwise", help: L("Транскрибировать заново")) {
                        retranscribe(record)
                    }
                }
                DSIconAction("trash", help: L("Удалить"), hoverAccent: true) {
                    if playback.playingID == record.id {
                        playback.stop()
                    }
                    store.delete(record.id)
                }
            }

            Text(record.text)
                .font(Tokens.sans(13))
                .lineSpacing(3.5)
                .foregroundStyle(Tokens.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    playback.toggle(record.id, url: store.audioURL(for: record))
                } label: {
                    Image(systemName: playback.isPlaying(record.id) ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.text)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()

                DSProgressBar(fraction: playback.playingID == record.id ? CGFloat(playback.progress) : 0)

                Text(record.durationLabel)
                    .font(Tokens.mono(11, weight: .medium))
                    .foregroundStyle(Tokens.text3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tokens.border, lineWidth: 1))
    }

    private func retranscribe(_ record: HistoryRecord) {
        retranscribingID = record.id
        Task {
            defer { retranscribingID = nil }
            guard let samples = try? store.samples(for: record) else { return }
            await coordinator.models.ensureLoaded()
            guard let text = try? await coordinator.models.transcribe(samples, options: .fromPrefs),
                  !text.isEmpty else { return }
            store.updateText(record.id, text: text)
        }
    }

    // MARK: - Мелочи

    private func settingRow(
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Tokens.sans(13)).foregroundStyle(Tokens.text)
                if let subtitle {
                    Text(subtitle).font(Tokens.sans(11.5)).foregroundStyle(Tokens.text3)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 12)
    }
}
