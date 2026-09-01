import SwiftUI

/// The answer to a caught question, in its own window to the left of the panel.
/// Separate on purpose: the conversation keeps flowing while the answer is read,
/// and a bubble in the middle of it would push the call out of view.
struct MeetingAnswerView: View {
    let coordinator: RecordingCoordinator

    private var answer: MeetingAnswer { coordinator.meetingAnswer }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Tokens.surface2)
            body(for: answer.phase)
        }
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Tokens.cardBorder, lineWidth: 1)
        )
        .shadow(color: Tokens.shadowHUD.opacity(0.18), radius: 20, y: 10)
        .padding(6)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(answer.question)
                .font(Tokens.sans(13, weight: .medium))
                .lineSpacing(3)
                .foregroundStyle(Tokens.text)
                .lineLimit(3)
            Spacer(minLength: 8)
            CircleIconButton(symbol: "xmark", help: L("Закрыть")) {
                answer.dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func body(for phase: MeetingAnswer.Phase) -> some View {
        switch phase {
        case .asking:
            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                Text(L("Ищу ответ…"))
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(Tokens.text3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            Text(message)
                .font(Tokens.sans(12.5))
                .foregroundStyle(Tokens.accentHover)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .answered, .idle:
            ScrollView {
                Text(answer.text)
                    .font(Tokens.sans(13.5))
                    .lineSpacing(5)
                    .foregroundStyle(Tokens.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
            }
        }
    }
}
