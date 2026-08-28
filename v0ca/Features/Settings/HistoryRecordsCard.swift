import AppKit
import SwiftUI

/// Card with record rows (shared by History and Dictation): tabular
/// time/text/actions rows, actions visible only on hover, hover
/// highlights the row full-width. The player is passed in from outside so
/// only one record plays at a time across the whole tab.
struct HistoryRecordsCard: View {
    let coordinator: RecordingCoordinator
    let records: [HistoryRecord]
    let playback: PlaybackController

    var body: some View {
        // LazyVStack: in Dictation the whole day is a single card, and without
        // lazy rows a hundred records would lay out at once.
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

/// A single record row. Separate view with its own hover/copy state:
/// cursor movement redraws only this row, not the whole day card —
/// otherwise scrolling a large history stutters (every hover rebuilt all rows).
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

            // Text selection makes Text expensive; enable it only for the
            // row under the cursor, the rest render the cheap way.
            Group {
                if hovered {
                    recordText.textSelection(.enabled)
                } else {
                    recordText
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions strictly on hover: move the cursor off the row and they hide.
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
        // Explicit background shape: without it the system rounds the highlight
        // into a pill, but it must cover the row edge to edge with square corners.
        .background(Rectangle().fill(hovered ? Tokens.surfaceHover : .clear))
        .onHover { hovered = $0 }
    }

    /// A dictation is just its text. An answer from a model gets what was asked
    /// above it: the spoken question in a tinted bubble, or — for a screenshot
    /// sent in silence — a plain label, because the picture itself was never kept.
    @ViewBuilder
    private var recordText: some View {
        if record.kind == .dictation {
            answerText
        } else {
            VStack(alignment: .leading, spacing: 7) {
                if let question = record.question, !question.isEmpty {
                    questionBubble(question)
                } else if record.kind == .screen {
                    screenshotLabel
                }
                answerText
            }
        }
    }

    private var answerText: some View {
        Text(record.text)
            .font(Tokens.sans(13.5))
            .lineSpacing(4)
            .foregroundStyle(Tokens.text)
    }

    /// Speech bubble with the tail on the top left, as in the mockup.
    private func questionBubble(_ question: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: record.kind == .screen ? "display" : "bubble.left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 2)
            Text(question)
                .font(Tokens.sans(13))
                .lineSpacing(3)
                .foregroundStyle(Tokens.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 14,
                bottomTrailingRadius: 14, topTrailingRadius: 14
            )
            .fill(tint.opacity(0.12))
        )
    }

    /// Not a button and not a link: there is no screenshot to open.
    private var screenshotLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: "display")
                .font(.system(size: 11, weight: .medium))
            Text(L("Снимок экрана"))
                .font(Tokens.sans(12.5, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 4, bottomLeadingRadius: 14,
                bottomTrailingRadius: 14, topTrailingRadius: 14
            )
            .fill(tint.opacity(0.12))
        )
    }

    private var tint: Color {
        record.kind == .screen ? Tokens.capture : Tokens.remote
    }

    // MARK: - Row actions

    @ViewBuilder
    private var actions: some View {
        if record.kind == .dictation {
            dictationActions
        }
        if copied {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.success)
                .frame(width: 16, height: 16)
        } else {
            HistoryAction(symbol: "doc.on.doc", help: L("Скопировать")) {
                copy()
            }
        }
        HistoryAction(symbol: "trash", help: L("Удалить"), hoverAccent: true) {
            if playback.playingID == record.id {
                playback.stop()
            }
            store.delete(record.id)
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.text, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }

    @ViewBuilder
    private var dictationActions: some View {
        HistoryAction(
            symbol: playback.isPlaying(record.id) ? "pause.fill" : "play.fill",
            filled: true,
            help: playback.isPlaying(record.id) ? L("Стоп") : L("Воспроизвести")
        ) {
            if let url = store.audioURL(for: record) {
                playback.toggle(record.id, url: url)
            }
            coordinator.achievements.mark(.playback)
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
            coordinator.achievements.mark(.retranscribe)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// History row action icon: 16px, gray, darkens on hover
/// (`hoverAccent` turns it red, for delete). No background or border, as in the mockup.
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
