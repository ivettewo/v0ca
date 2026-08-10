import AppKit
import SwiftUI

/// Карточка со строками записей (общая для «Истории» и «Диктовки»): табличные
/// строки время/текст/действия, действия видны только при наведении, ховер
/// подсвечивает строку во всю ширину. Плеер передаётся снаружи, чтобы в один
/// момент играла одна запись на всю вкладку.
struct HistoryRecordsCard: View {
    let coordinator: RecordingCoordinator
    let records: [HistoryRecord]
    let playback: PlaybackController

    var body: some View {
        // LazyVStack: у «Диктовки» весь день — одна карточка, и без ленивых
        // строк сотня записей лейаутится разом.
        LazyVStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                if index > 0 {
                    RowDivider()
                }
                HistoryRecordRow(coordinator: coordinator, record: record, playback: playback)
            }
        }
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: Tokens.radiusCard).stroke(Tokens.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.radiusCard))
    }
}

/// Одна строка записи. Отдельная вью с собственным стейтом ховера/копирования:
/// движение курсора перерисовывает только эту строку, а не всю карточку дня —
/// иначе скролл большой истории лагает (каждый ховер перестраивал все строки).
private struct HistoryRecordRow: View {
    let coordinator: RecordingCoordinator
    let record: HistoryRecord
    let playback: PlaybackController

    @State private var hovered = false
    @State private var copied = false
    @State private var retranscribing = false

    private var store: HistoryStore { coordinator.history }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(Self.timeFormatter.string(from: record.date))
                .font(Tokens.mono(11.5, weight: .medium))
                .foregroundStyle(Tokens.text3)
                .frame(width: 48, alignment: .leading)
                .padding(.top, 2)

            // Выделение текста — тяжёлое представление Text; включаем только
            // у строки под курсором, остальные рисуются лёгким путём.
            Group {
                if hovered {
                    recordText.textSelection(.enabled)
                } else {
                    recordText
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Действия — строго при наведении: убрал курсор со строки — скрылись.
            HStack(spacing: 14) {
                if hovered {
                    actions
                }
            }
            .frame(width: 120, alignment: .trailing)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        // Форма фона явная: без неё система скругляет подсветку «пилюлей»,
        // а она должна закрывать строку от края до края прямыми углами.
        .background(Rectangle().fill(hovered ? Tokens.surfaceHover : .clear))
        .onHover { hovered = $0 }
    }

    private var recordText: some View {
        Text(record.text)
            .font(Tokens.sans(13.5))
            .lineSpacing(4)
            .foregroundStyle(Tokens.text)
    }

    // MARK: - Действия строки

    @ViewBuilder
    private var actions: some View {
        HistoryAction(
            symbol: playback.isPlaying(record.id) ? "pause.fill" : "play.fill",
            filled: true,
            help: playback.isPlaying(record.id) ? L("Стоп") : L("Воспроизвести")
        ) {
            playback.toggle(record.id, url: store.audioURL(for: record))
        }

        if copied {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.success)
                .frame(width: 16, height: 16)
        } else {
            HistoryAction(symbol: "doc.on.doc", help: L("Скопировать")) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(record.text, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            }
        }

        if retranscribing {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
                .frame(width: 16, height: 16)
        } else {
            HistoryAction(symbol: "arrow.clockwise", help: L("Транскрибировать заново")) {
                retranscribe()
            }
        }

        HistoryAction(symbol: "trash", help: L("Удалить"), hoverAccent: true) {
            if playback.playingID == record.id {
                playback.stop()
            }
            store.delete(record.id)
        }
    }

    private func retranscribe() {
        retranscribing = true
        Task {
            defer { retranscribing = false }
            guard let samples = try? store.samples(for: record) else { return }
            await coordinator.models.ensureLoaded()
            guard let text = try? await coordinator.models.transcribe(samples, options: .fromPrefs),
                  !text.isEmpty else { return }
            store.updateText(record.id, text: text)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// Иконка-действие строки истории: 16px, серым, на ховере темнеет
/// (`hoverAccent` — краснеет, для удаления). Без фона и рамки, как в макете.
private struct HistoryAction: View {
    let symbol: String
    var filled: Bool = false
    let help: String
    var hoverAccent: Bool = false
    let action: () -> Void

    @State private var hovering = false

    init(symbol: String, filled: Bool = false, help: String,
         hoverAccent: Bool = false, action: @escaping () -> Void) {
        self.symbol = symbol
        self.filled = filled
        self.help = help
        self.hoverAccent = hoverAccent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: filled ? 13 : 12.5, weight: .medium))
                .foregroundStyle(hovering ? (hoverAccent ? Tokens.accentHover : Tokens.text) : Tokens.text2)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .help(help)
    }
}
