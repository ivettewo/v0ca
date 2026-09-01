import SwiftUI

/// The conversation panel per the meeting mockup: a title that can be renamed,
/// the call as bubbles, and the actions along the bottom.
///
/// Bubbles carry no names on purpose. The side is known because it comes from
/// the source — microphone or system audio — and nothing here guesses who is
/// speaking, so nothing here can be wrong about it.
struct MeetingPanelView: View {
    let coordinator: RecordingCoordinator

    @FocusState private var titleFocused: Bool

    private var recorder: MeetingRecorder { coordinator.meeting }
    private var transcript: MeetingTranscript { coordinator.meetingTranscript }
    private var questions: QuestionCatcher { coordinator.meetingQuestions }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Tokens.surface2)
            content
            if recorder.isRunning || !transcript.lines.isEmpty {
                Divider().overlay(Tokens.surface2)
                footer
            }
        }
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Tokens.cardBorder, lineWidth: 1)
        )
        .shadow(color: Tokens.shadowHUD.opacity(0.18), radius: 20, y: 10)
        .padding(6)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            TextField(L("Без названия"), text: Binding(
                get: { transcript.title },
                set: { transcript.title = $0 }
            ))
                .textFieldStyle(.plain)
                .font(Tokens.sans(14, weight: .medium))
                .foregroundStyle(Tokens.text)
                .focused($titleFocused)
                .lineLimit(1)

            Spacer(minLength: 8)

            if recorder.isRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Tokens.accent)
                        .frame(width: 7, height: 7)
                    Text(transcript.isWorking ? L("Распознаю…") : L("Идёт запись"))
                        .font(Tokens.sans(11.5))
                        .foregroundStyle(Tokens.text3)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Lines

    @ViewBuilder
    private var content: some View {
        if transcript.lines.isEmpty {
            empty
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(transcript.lines) { line in
                            bubble(line)
                                .id(line.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onChange(of: transcript.lines.count) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Text(recorder.isRunning ? L("Слушаю…") : L("Запись не идёт"))
                .font(Tokens.sans(13, weight: .medium))
                .foregroundStyle(Tokens.text2)
            Text(recorder.isRunning
                ? L("Реплики появятся здесь, как только кто-нибудь заговорит.")
                : L("Задайте название сверху, а затем начните запись — ваши реплики белым, собеседника тёмным."))
                .font(Tokens.sans(12.5))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Tokens.text3)

            if !recorder.isRunning {
                DSButton(variant: .primary) {
                    Task { await coordinator.toggleMeeting() }
                } label: {
                    Text(L("Начать"))
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Dark and leading for the other side, white and trailing for you — the
    /// shape carries the speaker, so no label has to.
    private func bubble(_ line: MeetingLine) -> some View {
        let mine = line.side == .me
        let asked = questions.caught?.lineID == line.id
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(line.text)
                .font(Tokens.sans(13.5))
                .lineSpacing(4)
                .foregroundStyle(mine && !asked ? Tokens.text : Tokens.textOnAccent)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: mine ? 20 : 8,
                        bottomTrailingRadius: mine ? 8 : 20,
                        topTrailingRadius: 20
                    )
                    .fill(asked ? Tokens.accent : (mine ? Tokens.surface : Tokens.text))
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: mine ? 20 : 8,
                        bottomTrailingRadius: mine ? 8 : 20,
                        topTrailingRadius: 20
                    )
                    .stroke(mine ? Tokens.border : .clear, lineWidth: 1)
                )
                .frame(maxWidth: 284, alignment: mine ? .trailing : .leading)
            if !mine { Spacer(minLength: 40) }
        }
        // The question the panel caught carries its own actions, so the offer is
        // where the question is rather than in a corner somewhere.
        .overlay(alignment: .bottomLeading) {
            if asked {
                questionActions
                    .offset(y: 20)
            }
        }
        .padding(.bottom, asked ? 24 : 0)
    }

    private var questionActions: some View {
        HStack(spacing: 6) {
            Button {
                coordinator.answerCaughtQuestion()
            } label: {
                Text(L("Ответ"))
                    .font(Tokens.sans(12, weight: .medium))
                    .foregroundStyle(Tokens.accentHover)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            // Bound to the panel, not the system: it fires only while this
            // window has the keys, so ⌘C keeps meaning copy everywhere else.
            .keyboardShortcut(.return, modifiers: .command)

            Text("·")
                .font(Tokens.sans(12))
                .foregroundStyle(Tokens.text3)

            Button {
                guard let caught = questions.caught else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(caught.question, forType: .string)
            } label: {
                Text(L("Копия"))
                    .font(Tokens.sans(12, weight: .medium))
                    .foregroundStyle(Tokens.text2)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .keyboardShortcut("c", modifiers: .command)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            CircleIconButton(symbol: "doc.on.doc", help: L("Скопировать разговор")) {
                copyAll()
            }
            Spacer(minLength: 8)
            DSButton(variant: recorder.isRunning ? .dangerSoft : .primary) {
                Task { await coordinator.toggleMeeting() }
            } label: {
                Text(recorder.isRunning ? L("Завершить") : L("Начать"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func copyAll() {
        let text = transcript.lines
            .map { "\($0.side == .me ? L("Я") : L("Собеседник")): \($0.text)" }
            .joined(separator: "\n")
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
