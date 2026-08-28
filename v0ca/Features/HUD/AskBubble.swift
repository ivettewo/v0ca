import AppKit
import SwiftUI

/// The "Ask" bubble above the bar: the recognized question, a countdown before
/// it leaves the Mac, then the answer. Capped at a few lines and scrolls inside —
/// an answer of any length must not turn the HUD into a full-screen window.
struct AskBubble: View {
    let session: AskSession

    @State private var shimmer = false
    @State private var textHeight: CGFloat = 0
    @State private var copied = false
    @State private var barProgress: CGFloat = 0
    @State private var copyResetTask: Task<Void, Never>?

    /// Six full lines of 13pt text at 5pt line spacing — measured, not guessed:
    /// at 122 the sixth line was cut through the middle.
    private static let maxTextHeight: CGFloat = 132
    /// With a thumbnail on top the cap has to cover the picture as well, or the
    /// question under it is swallowed by the fade.
    private static let maxShotHeight: CGFloat = 100
    /// How much of the bottom edge dissolves, and how much room the content needs
    /// below it so the last line can be read in full.
    private static let fadeHeight: CGFloat = 28
    private static let maxTextWithShot: CGFloat = maxShotHeight + 10 + 84
    private static let width: CGFloat = 402

    /// Fit the screenshot into the bubble: capped by height, and by width on a
    /// very wide display.
    private static func thumbnailSize(_ source: NSSize) -> NSSize {
        let ratio = source.width / max(source.height, 1)
        let width = min(width - 36, maxShotHeight * ratio)
        return NSSize(width: width, height: width / ratio)
    }

    /// The bubble wears the colour of the mode that opened it: violet for a
    /// spoken question, blue when a screenshot is going out with it.
    private var tint: Color {
        session.preview == nil ? Tokens.remote : Tokens.capture
    }

    /// How tall the scrolling area is allowed to get before it starts scrolling.
    private var cap: CGFloat {
        session.preview == nil ? Self.maxTextHeight : Self.maxTextWithShot
    }

    /// The content is taller than the cap, so part of it is hidden below.
    private var scrollable: Bool {
        textHeight > cap
    }

    private var isAnswer: Bool {
        if case .answered = session.phase { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            text
            footer
        }
        .frame(width: Self.width)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Tokens.shadowHUD.opacity(0.16), radius: 22, y: 10)
    }

    // MARK: - Text

    private var text: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Group {
                // Only the answer comes back as Markdown — the question is
                // dictated speech and has nothing to format.
                if isAnswer {
                    AnswerText(raw: session.answer)
                } else if let preview = session.preview {
                    VStack(alignment: .leading, spacing: 10) {
                    // The "Screen" mode has no spoken question — what is about to
                    // leave the Mac is the picture, so that is what to show.
                    // The size is computed rather than left to `aspectRatio`: that
                    // modifier fits the *content* but keeps the view at the full
                    // proposed width, so the border ended up floating around a
                    // centred picture instead of hugging it.
                    let size = Self.thumbnailSize(preview.size)
                    Image(nsImage: preview)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Tokens.surface2, lineWidth: 1)
                        )
                        if session.showsQuestion {
                            Text(session.question)
                                .font(Tokens.sans(13))
                                .lineSpacing(5)
                                .foregroundStyle(Tokens.text)
                        }
                    }
                } else {
                    Text(displayText)
                        .font(Tokens.sans(13))
                        .lineSpacing(5)
                        .foregroundStyle(Tokens.text)
                }
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.disabled)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: TextHeightKey.self, value: proxy.size.height)
                    }
                }
                // Without this the last line can never be scrolled clear of the
                // fade at the bottom — it stays half-dissolved however far you
                // scroll. Measured above the padding, so a short answer still hugs.
                .padding(.bottom, scrollable ? Self.fadeHeight : 0)
        }
        // A ScrollView takes all the height it is offered, so a one-line question
        // would still open a six-line box. Measure the text and take the smaller
        // of the two: short answers hug, long ones stop at the cap and scroll.
        .frame(height: min(max(textHeight, 18), cap))
        // When there is more text below, the last line dissolves instead of being
        // cut mid-glyph — so the edge reads as "keep scrolling", not as a bug.
        // Nothing to hide when everything fits, so the mask stays opaque then.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(
                        color: .black,
                        location: scrollable ? 1 - Self.fadeHeight / cap : 1
                    ),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .onPreferenceChange(TextHeightKey.self) { textHeight = $0 }
        .padding(.horizontal, 18)
        .padding(.top, 15)
        .padding(.bottom, 14)
        // While the question is in flight the words go out of focus and a
        // shimmer runs across them — the same idea as a skeleton row.
        .blur(radius: session.phase == .asking ? 7 : 0)
        .opacity(session.phase == .asking ? 0.8 : 1)
        .overlay {
            if session.phase == .asking {
                skeleton
            }
        }
        .animation(.easeInOut(duration: 0.28), value: session.phase)
    }

    private var skeleton: some View {
        GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.32),
                    .init(color: tint.opacity(0.18), location: 0.5),
                    .init(color: .clear, location: 0.68),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(width: proxy.size.width * 2.6)
            .offset(x: shimmer ? proxy.size.width : -proxy.size.width * 2.6)
        }
        .allowsHitTesting(false)
        .onAppear {
            shimmer = false
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }

    private var displayText: String {
        switch session.phase {
        case .answered: session.answer
        case .failed(let message): message
        default: session.question
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch session.phase {
        case .countdown:
            countdownRow
        case .answered:
            actionsRow
        case .failed:
            failureRow
        case .asking, .idle:
            EmptyView()
        }
    }

    /// The bar doubles as a button: clicking it sends the question right away
    /// instead of waiting out the countdown.
    private var countdownRow: some View {
        Button {
            session.sendNow()
        } label: {
            HStack(spacing: 13) {
                Capsule()
                    .fill(tint.opacity(0.14))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * barProgress)
                        }
                    }
                    .clipShape(Capsule())
                    // One linear animation for the whole countdown instead of a
                    // width recomputed on every tick: the render server carries it,
                    // so it is both smoother and cheaper than ticking faster.
                    .onAppear { startBar() }
                    .onChange(of: session.phase) { _, _ in startBar() }
                Text(L("%@ с", String(format: "%.0f", session.remaining.rounded(.up))))
                    .font(Tokens.mono(12, weight: .medium))
                    .foregroundStyle(Tokens.text2)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(L("Отправить сразу"))
        .overlay(alignment: .top) { divider }
        .overlay(alignment: .bottom) {
            Text(L("Клик — отправить сразу · Esc — отменить"))
                .font(Tokens.sans(10.5))
                .foregroundStyle(Tokens.text3)
                .padding(.bottom, -16)
        }
        .padding(.bottom, 18)
    }

    private func startBar() {
        guard session.phase == .countdown else { return }
        var restart = Transaction()
        restart.disablesAnimations = true
        withTransaction(restart) { barProgress = 0 }
        withAnimation(.linear(duration: session.remaining)) { barProgress = 1 }
    }

    private var actionsRow: some View {
        HStack(spacing: 7) {
            // Copying gives no visible result anywhere else on screen, so the
            // button has to confirm it itself — same checkmark as in History.
            roundAction(
                copied ? "checkmark" : "doc.on.doc",
                help: L("Скопировать"),
                tint: copied ? Tokens.success : Tokens.text2
            ) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(session.answer, forType: .string)
                copied = true
                copyResetTask?.cancel()
                copyResetTask = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    copied = false
                }
            }
            roundAction("arrow.clockwise", help: L("Перегенерировать")) {
                session.regenerate()
            }
            Spacer(minLength: 12)
            roundAction("xmark", help: L("Закрыть")) {
                session.dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 15)
    }

    private var failureRow: some View {
        HStack(spacing: 7) {
            roundAction("arrow.clockwise", help: L("Повторить")) {
                session.regenerate()
            }
            Spacer(minLength: 12)
            roundAction("xmark", help: L("Закрыть")) {
                session.dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 15)
    }

    private var divider: some View {
        Rectangle()
            .fill(Tokens.surface2)
            .frame(height: 1)
    }

    private func roundAction(
        _ symbol: String, help: String, tint: Color = Tokens.text2,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
                .background(Tokens.surface, in: Circle())
                .overlay(Circle().stroke(Tokens.controlBorder, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(help)
    }
}

/// Height of the bubble's text, measured so the box can hug short answers.
private struct TextHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
