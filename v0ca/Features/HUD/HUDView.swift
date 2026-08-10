import SwiftUI

/// Плавающая капсула — по дизайн-системе, вариант «M · 38 px».
///
/// Капсула одна на все состояния и никогда не пересоздаётся: меняется только её
/// ширина, а содержимое кроссфейдится внутри и обрезается краем (в макете —
/// `overflow: hidden`). Поэтому переходы читаются как «кружок → раскрылся →
/// сузился в кружок с галочкой», а не как подмена одной плашки другой.
struct HUDView: View {
    let coordinator: RecordingCoordinator

    /// Фаза показа. Отдельная от состояния координатора: в макете запись
    /// начинается с промежуточного кружка с точкой, который только потом
    /// раскрывается в полосу с волной.
    private enum Phase: Equatable {
        case hidden, dot, recording, processing, done
    }

    @State private var phase: Phase = .hidden
    /// Ширина строки «Расшифровка…» — она зависит от языка и от процента загрузки.
    @State private var processingWidth: CGFloat = 172
    @State private var checkDrawn = false
    @State private var phaseTask: Task<Void, Never>?

    /// Ширины из макета: 38 / 136 / 172.
    private var width: CGFloat {
        switch phase {
        case .hidden, .dot, .done: 38
        case .recording: 136
        case .processing: processingWidth
        }
    }

    // Пружина без отскока: с bounce капсула перелетает мимо конечной ширины и
    // возвращается — на глаз это дёрганье, а в момент схлопывания она успевает
    // стать уже 38px и выглядит яйцом.
    private let morph = Animation.spring(duration: 0.45, bounce: 0)
    private let crossfade = Animation.easeInOut(duration: 0.26)

    var body: some View {
        // Слои прижаты влево, как inset:0 + flex в макете: точка стоит на месте
        // (14px от края), а капсула растёт вправо — поэтому точка «уезжает влево»
        // относительно центра, а крестик выезжает справа.
        ZStack(alignment: .leading) {
            layer(dotContent, visible: phase == .dot)
            layer(recordingContent, visible: phase == .recording)
            layer(processingContent, visible: phase == .processing)
            // Галочка тянется на всю ширину капсулы и центрируется в ней: иначе
            // при схлопывании она стоит у левого края и уезжает вправо вместе с ним.
            layer(doneContent.frame(width: max(38, width), height: 38), visible: phase == .done)
        }
        // Ширина не меньше высоты — иначе капсула превращается в вертикальное яйцо.
        // alignment обязателен: содержимое шире капсулы, и без него SwiftUI
        // центрирует его в кадре — видно середину полосы, а не левый край с точкой.
        .frame(width: max(38, width), height: 38, alignment: .leading)
        .background(Tokens.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Tokens.border, lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: Tokens.shadowHUD.opacity(0.10), radius: 14, y: 6)
        .scaleEffect(phase == .hidden ? 0.55 : 1)
        .opacity(phase == .hidden ? 0 : 1)
        // Появление и исчезновение — короче морфа ширины, иначе непонятно,
        // в какой момент капсула уже ушла.
        .animation(.easeOut(duration: 0.3), value: phase == .hidden)
        .animation(morph, value: phase)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 4)
        .background(alignment: .bottom) { widthProbe }
        .onAppear { sync(to: coordinator.state) }
        .onChange(of: coordinator.state) { _, state in sync(to: state) }
    }

    /// Слой содержимого: показан/скрыт прозрачностью, размер не влияет на капсулу.
    private func layer(_ content: some View, visible: Bool) -> some View {
        content
            .fixedSize()
            .opacity(visible ? 1 : 0)
            .animation(crossfade, value: visible)
            .allowsHitTesting(visible)
    }

    // MARK: - Содержимое фаз

    /// Промежуточная фаза старта: кружок с точкой. Точка стоит там же, где потом
    /// окажется мигающая точка записи (14px от левого края) — поэтому при
    /// раскрытии она не «перепрыгивает», а остаётся на месте.
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

    /// Галочка рисуется штрихом, а не появляется целиком (в макете — vdrawFast).
    private var doneContent: some View {
        CheckmarkShape()
            .trim(from: 0, to: checkDrawn ? 1 : 0)
            .stroke(Tokens.success, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 16, height: 16)
            .frame(width: 38, height: 38)
    }

    /// Невидимая копия строки расшифровки — из неё берём ширину капсулы, чтобы
    /// текст не обрезался на других языках и на «Модель… 100%».
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

    // MARK: - Синхронизация с координатором

    private func sync(to state: RecordingCoordinator.State) {
        phaseTask?.cancel()
        switch state {
        case .recording:
            // Из скрытого — сначала кружок, через 0.42s раскрытие (в макете 260→680 мс).
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
                // Пауза, чтобы штрих пошёл уже по схлопнувшемуся кружку.
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

    /// Крестик по дизайн-системе: круг 28px #ECECEF, иконка 13px, цвет text2.
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

/// Ширина содержимого фазы расшифровки — измеряется скрытой копией.
private struct WidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Галочка из макета: viewBox 20×20, путь `M4 10.5 l4 4 l8 -9`.
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
