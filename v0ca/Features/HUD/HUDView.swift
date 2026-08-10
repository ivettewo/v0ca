import SwiftUI

/// Floating capsule — per the design system, "M · 38 px" variant.
///
/// A single capsule serves all states and is never recreated: only its width
/// changes, while the content crossfades inside and is clipped by the edge
/// (`overflow: hidden` in the mockup). That's why transitions read as
/// "dot → expanded → collapsed into a checkmark circle" rather than one pill
/// being swapped for another.
struct HUDView: View {
    let coordinator: RecordingCoordinator

    /// Display phase. Separate from the coordinator state: in the mockup,
    /// recording starts with an intermediate dot circle that only then
    /// expands into the waveform bar.
    private enum Phase: Equatable {
        case hidden, dot, recording, processing, done
    }

    @State private var phase: Phase = .hidden
    /// Width of the "Transcribing…" row — it depends on the language and the download percentage.
    @State private var processingWidth: CGFloat = 172
    @State private var checkDrawn = false
    @State private var phaseTask: Task<Void, Never>?

    /// Widths from the mockup: 38 / 136 / 172.
    private var width: CGFloat {
        switch phase {
        case .hidden, .dot, .done: 38
        case .recording: 136
        case .processing: processingWidth
        }
    }

    // Spring with no bounce: with bounce the capsule overshoots the target width
    // and comes back — it reads as jitter, and during the collapse it briefly gets
    // narrower than 38px and looks like an egg.
    private let morph = Animation.spring(duration: 0.45, bounce: 0)
    private let crossfade = Animation.easeInOut(duration: 0.26)

    var body: some View {
        // Layers are pinned to the left, like inset:0 + flex in the mockup: the dot
        // stays put (14px from the edge) while the capsule grows to the right — so the
        // dot "drifts left" relative to the center and the cross slides in from the right.
        ZStack(alignment: .leading) {
            layer(dotContent, visible: phase == .dot)
            layer(recordingContent, visible: phase == .recording)
            layer(processingContent, visible: phase == .processing)
            // The checkmark spans the full capsule width and is centered in it: otherwise
            // during the collapse it sits at the left edge and slides right along with it.
            layer(doneContent.frame(width: max(38, width), height: 38), visible: phase == .done)
        }
        // Width never smaller than the height — otherwise the capsule turns into a vertical egg.
        // alignment is required: the content is wider than the capsule, and without it SwiftUI
        // centers it in the frame — you'd see the middle of the bar, not the left edge with the dot.
        .frame(width: max(38, width), height: 38, alignment: .leading)
        .background(Tokens.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Tokens.border, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: Tokens.shadowHUD.opacity(0.10), radius: 14, y: 6)
        .scaleEffect(phase == .hidden ? 0.55 : 1)
        .opacity(phase == .hidden ? 0 : 1)
        // Appear/disappear is shorter than the width morph — otherwise it's unclear
        // at which point the capsule is already gone.
        .animation(.easeOut(duration: 0.3), value: phase == .hidden)
        .animation(morph, value: phase)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 4)
        .background(alignment: .bottom) { widthProbe }
        .onAppear { sync(to: coordinator.state) }
        .onChange(of: coordinator.state) { _, state in sync(to: state) }
    }

    /// Content layer: shown/hidden via opacity; its size doesn't affect the capsule.
    private func layer(_ content: some View, visible: Bool) -> some View {
        content
            .fixedSize()
            .opacity(visible ? 1 : 0)
            .animation(crossfade, value: visible)
            .allowsHitTesting(visible)
    }

    // MARK: - Phase content

    /// Intermediate start phase: a circle with a dot. The dot sits exactly where the
    /// blinking recording dot will be (14px from the left edge) — so it doesn't
    /// "jump" on expansion, it stays in place.
    private var dotContent: some View {
        Circle()
            .fill(Tokens.accent)
            .frame(width: 8, height: 8)
            .padding(.leading, 14)
            .frame(width: 38, height: 38, alignment: .leading)
    }

    private var recordingContent: some View {
        HStack(spacing: 11) {
            BlinkingDot()
            WaveBars(level: coordinator.level)
            cancelButton
        }
        .padding(.leading, 14)
        .padding(.trailing, 5)
    }

    private var processingContent: some View {
        HStack(spacing: 9) {
            SpinnerRing()
            Text(processingLabel)
                .font(Tokens.sans(12.5))
                .foregroundStyle(Tokens.text2)
                .lineLimit(1)
                .fixedSize()
            cancelButton
        }
        .padding(.leading, 13)
        .padding(.trailing, 5)
    }

    /// The checkmark is stroke-drawn rather than appearing at once (vdrawFast in the mockup).
    private var doneContent: some View {
        CheckmarkShape()
            .trim(from: 0, to: checkDrawn ? 1 : 0)
            .stroke(Tokens.success, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16)
            .frame(width: 38, height: 38)
    }

    /// Hidden copy of the processing row — the capsule width is taken from it so the
    /// text doesn't get clipped in other languages or on "Model… 100%".
    private var widthProbe: some View {
        processingContent
            .fixedSize()
            .hidden()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(WidthKey.self) { measured in
                if measured > 0 { processingWidth = measured }
            }
    }

    // MARK: - Sync with the coordinator

    private func sync(to state: RecordingCoordinator.State) {
        phaseTask?.cancel()
        switch state {
        case .recording:
            // From hidden: dot circle first, then expand after 0.42s (260→680ms in the mockup).
            guard phase == .hidden else { phase = .recording; return }
            phase = .dot
            phaseTask = Task {
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled, coordinator.state == .recording else { return }
                phase = .recording
            }
        case .processing:
            phase = .processing
        case .done:
            phase = .done
            checkDrawn = false
            phaseTask = Task {
                // Pause so the stroke draws on the already collapsed circle.
                try? await Task.sleep(for: .milliseconds(140))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) { checkDrawn = true }
            }
        case .hidden:
            phase = .hidden
            checkDrawn = false
        }
    }

    private var processingLabel: String {
        switch coordinator.modelState {
        case .downloading(let percent): "\(L("Модель…")) \(percent)%"
        case .loading: L("Подготовка…")
        case .failed: L("Ошибка модели")
        case .idle, .ready: L("Расшифровка…")
        }
    }

    /// Cancel cross per the design system: 28px #ECECEF circle, 13px icon, text2 color.
    private var cancelButton: some View {
        Button {
            coordinator.cancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tokens.text2)
                .frame(width: 28, height: 28)
                .background(Tokens.surface2, in: Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Width of the processing-phase content — measured via the hidden copy.
private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Checkmark from the mockup: viewBox 20×20, path `M4 10.5 l4 4 l8 -9`.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 20
        var path = Path()
        path.move(to: CGPoint(x: 4 * scale, y: 10.5 * scale))
        path.addLine(to: CGPoint(x: 8 * scale, y: 14.5 * scale))
        path.addLine(to: CGPoint(x: 16 * scale, y: 5.5 * scale))
        return path
    }
}

/// Live voice waveform: ten 3px bars (radius 2, gap 3), height driven by the mic level.
private struct WaveBars: View {
    let level: Float

    private static let factors: [CGFloat] = [0.45, 0.8, 0.6, 1.0, 0.7, 0.9, 0.55, 0.85, 0.65, 0.5]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Tokens.text2)
                    .frame(width: 3, height: 4 + CGFloat(level) * 16 * Self.factors[index])
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
        .frame(height: 22)
    }
}

/// Spinner per the design system: 14px ring, rgba(155,155,163,.28) track, #9B9BA3 segment.
private struct SpinnerRing: View {
    @State private var rotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Tokens.text3.opacity(0.28), lineWidth: 2)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Tokens.text3, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(rotating ? 360 : 0))
        }
        .frame(width: 14, height: 14)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotating = true
            }
        }
    }
}

private struct BlinkingDot: View {
    @State private var visible = true

    var body: some View {
        Circle()
            .fill(Tokens.accent)
            .frame(width: 8, height: 8)
            .opacity(visible ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
