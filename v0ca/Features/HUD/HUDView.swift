import SwiftUI

/// Плавающая капсула — по дизайн-системе, вариант «M · 38 px»:
/// белый фон, рамка #E3E3E7, ширина по содержимому, высота 38.
struct HUDView: View {
    let coordinator: RecordingCoordinator

    var body: some View {
        Group {
            switch coordinator.state {
            case .hidden:
                Color.clear.frame(width: 1, height: 1)
            case .recording:
                capsule {
                    HStack(spacing: 11) {
                        BlinkingDot()
                        WaveBars(level: coordinator.level)
                        cancelButton
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 5)
                }
            case .processing:
                capsule {
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
            case .done:
                capsule {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Tokens.success)
                        .frame(width: 38, height: 38)
                }
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.25), value: coordinator.state)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 4)
    }

    private func capsule(@ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(height: 38)
            .background(Tokens.surface, in: Capsule())
            .overlay(Capsule().stroke(Tokens.border, lineWidth: 1))
            .shadow(color: Color(hex: 0x182030).opacity(0.10), radius: 14, y: 6)
            .transition(.scale(scale: 0.55).combined(with: .opacity))
    }

    private var processingLabel: String {
        switch coordinator.modelState {
        case .downloading(let percent): "\(L("Модель…")) \(percent)%"
        case .loading: L("Подготовка…")
        case .failed: L("Ошибка модели")
        case .idle, .ready: L("Расшифровка…")
        }
    }

    /// Крестик по дизайн-системе: круг 28px #ECECEF, иконка 13px, цвет text2.
    private var cancelButton: some View {
        Button {
            coordinator.cancel()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tokens.text2)
                .frame(width: 28, height: 28)
                .background(Color(hex: 0xECECEF), in: Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Живая волна от голоса: 10 полос 3px (радиус 2, gap 3), высота от уровня микрофона.
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

/// Спиннер по дизайн-системе: кольцо 14px, трек rgba(155,155,163,.28), сегмент #9B9BA3.
private struct SpinnerRing: View {
    @State private var rotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: 0x9B9BA3).opacity(0.28), lineWidth: 2)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Color(hex: 0x9B9BA3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
