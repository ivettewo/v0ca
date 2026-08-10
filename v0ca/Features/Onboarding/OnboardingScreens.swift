import AVFoundation
import ApplicationServices
import SwiftUI

// MARK: - 01A · Интро

/// Логотип на градиенте + подзаголовок. Шрифт логотипа — системный mono,
/// как везде в приложении (Unbounded из ранних макетов не используем).
struct OnboardingIntroScreen: View {
    let start: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                OnboardingGradient(HeaderGradient.intro, height: 420, fade: (from: 0.18, to: 0.62))
                VStack(spacing: 14) {
                    AnimatedLogo()

                    Text(L("Голос — в текст, в любом приложении. Всё распознаётся локально на вашем устройстве. Три шага — и можно говорить."))
                        .font(Tokens.sans(14))
                        .foregroundStyle(Tokens.text2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 390)
                }
                .padding(.horizontal, 44)
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter {
                OnboardingPillButton(L("Начать настройку"), variant: .primary, action: start)
            }
        }
    }
}

/// Логотип «v0ca.» с анимацией из макета (keyframes `vletter`): каждая буква
/// всплывает снизу с фейдом, задержки ступенькой, держится и растворяется;
/// цикл 7 секунд. Точка — акцентная.
private struct AnimatedLogo: View {
    private static let letters: [(char: String, accent: Bool, delay: Double)] = [
        ("v", false, 0), ("0", false, 0.12), ("c", false, 0.24), ("a", false, 0.36), (".", true, 0.5),
    ]

    /// cubic-bezier(.2,.7,.2,1) из макета.
    private static let curve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.2, y: 0.7),
        endControlPoint: UnitPoint(x: 0.2, y: 1)
    )

    private let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let now = OnboardingClock.elapsed(context.date, since: start)
            HStack(spacing: 0) {
                ForEach(Self.letters, id: \.char) { letter in
                    let state = Self.state(at: now, delay: letter.delay)
                    Text(letter.char)
                        .foregroundStyle(letter.accent ? Tokens.brand : Tokens.text)
                        .opacity(state.opacity)
                        .offset(y: state.offset)
                }
            }
            .font(Tokens.mono(56, weight: .semibold))
        }
    }

    /// Керфреймы как в макете (появление снизу → пауза → растворение), но цикл
    /// короче (3s против 7s в HTML) и рампы быстрее — чтобы между исчезновением
    /// и новым появлением не висела долгая пустота.
    private static func state(at time: Double, delay: Double) -> (opacity: Double, offset: Double) {
        let local = time - delay
        guard local >= 0 else { return (0, 14) }
        let phase = local.truncatingRemainder(dividingBy: 3) / 3
        switch phase {
        case ..<0.09:
            let t = curve.value(at: phase / 0.09)
            return (t, 14 * (1 - t))
        case ..<0.91:
            return (1, 0)
        default:
            let t = curve.value(at: (phase - 0.91) / 0.09)
            return (1 - t, 10 * t)
        }
    }
}

// MARK: - 01B · Мощно и бесплатно

/// Интерстишл: статичный мокап сайдбара настроек, уходящий в белое затухание,
/// снизу — заголовок с описанием. Анимации из HTML-макета пока не переносим.
struct OnboardingPowerFreeScreen: View {
    let back: () -> Void
    let next: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                OnboardingGradient(HeaderGradient.powerFree, fade: nil)
                sidebarMock
                    .padding(.top, 34)
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(L("Мощно и бесплатно"))
                            .font(Tokens.sans(32, weight: .semibold))
                            .foregroundStyle(Tokens.text)
                        Text(L("Никаких аккаунтов, подписок и лимитов — всё открыто с первого запуска."))
                            .font(Tokens.sans(14))
                            .foregroundStyle(Tokens.text2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 330)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .background(Tokens.surface)
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter(page: 1, back: back) {
                OnboardingPillButton(L("Дальше"), variant: .primary, action: next)
            }
        }
    }

    private let animationStart = Date()

    /// Мокап списка вкладок настроек; низ уходит в белый. Строки по очереди
    /// подсвечиваются (керфреймы `vtab` из макета: цикл 8s, задержки 0/2/4/6 —
    /// Общие, Звук, Модели, История; Словарь и Шорткаты статичные).
    private var sidebarMock: some View {
        TimelineView(.animation) { context in
            let now = OnboardingClock.elapsed(context.date, since: animationStart)
            VStack(spacing: 2) {
                mockRow("gearshape", L("Общие"), highlight: Self.highlight(at: now, delay: 0))
                mockRow("square.stack.3d.up", L("Модели"), highlight: Self.highlight(at: now, delay: 4))
                mockRow("mic", L("Звук"), highlight: Self.highlight(at: now, delay: 2))
                mockRow("clock.arrow.circlepath", L("История"), highlight: Self.highlight(at: now, delay: 6))
                mockRow("text.justify.left", L("Словарь"), highlight: 0)
                mockRow("keyboard", L("Шорткаты"), highlight: 0)
            }
        }
        .padding(10)
        .frame(width: 340)
        .background(Tokens.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.hairline, lineWidth: 1))
        .frame(height: 250, alignment: .top)
        // Затухание — внутри границ карточки, до clipped: иначе белый градиент
        // рисуется поверх фона экрана полосами вокруг карточки.
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: Tokens.surface.opacity(0), location: 0),
                    .init(color: Tokens.surface.opacity(0.75), location: 0.34),
                    .init(color: Tokens.surface, location: 0.68),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 190)
        }
        .clipped()
    }

    /// `highlight` 0…1 — сила подсветки: розовый фон и перекраска текста в красный
    /// (плавный кроссфейд двумя слоями — Color.mix требует macOS 15).
    private func mockRow(_ symbol: String, _ title: String, highlight: Double) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 17)
            Text(title)
                .font(Tokens.sans(13.5))
            Spacer()
        }
        .foregroundStyle(Tokens.text)
        .overlay(
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .frame(width: 17)
                Text(title)
                    .font(Tokens.sans(13.5))
                Spacer()
            }
            .foregroundStyle(Tokens.accentHover)
            .opacity(highlight)
        )
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Tokens.accentSoft.opacity(highlight), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Керфреймы `vtab`: цикл 8s, разгорается к 4%, горит до 21%, гаснет к 25%.
    private static func highlight(at time: Double, delay: Double) -> Double {
        let local = time - delay
        guard local >= 0 else { return 0 }
        let phase = local.truncatingRemainder(dividingBy: 8) / 8
        switch phase {
        case ..<0.04: return UnitCurve.easeInOut.value(at: phase / 0.04)
        case ..<0.21: return 1
        case ..<0.25: return 1 - UnitCurve.easeInOut.value(at: (phase - 0.21) / 0.04)
        default: return 0
        }
    }
}

// MARK: - 02A–04A · Разрешения

/// Шаг 1: карточки Микрофона и Универсального доступа с живыми состояниями
/// (кнопка «Разрешить» → спиннер «Запрос…» → бейдж «Разрешено»). «Далее»
/// активна только когда выданы оба разрешения; «Настроить позже» пропускает шаг.
struct OnboardingPermissionsScreen: View {
    let back: () -> Void
    let next: () -> Void

    @State private var micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var micRequesting = false
    @State private var axGranted = AXIsProcessTrusted()
    @State private var axRequested = false

    /// Разрешения выдаются в системных настройках, вне приложения —
    /// перечитываем раз в секунду, как на вкладке «Разрешения».
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var allGranted: Bool { micStatus == .authorized && axGranted }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                OnboardingGradient(HeaderGradient.permissions, fade: (from: 0.16, to: 0.6))
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        permissionCard(
                            title: L("Микрофон"),
                            subtitle: L("Запись голоса для расшифровки")
                        ) { micControl }
                        permissionCard(
                            title: L("Универсальный доступ"),
                            subtitle: L("Вставка готового текста в активное приложение")
                        ) { axControl }
                    }
                    Text(L("Оба разрешения обязательны — без них приложение не сможет работать."))
                        .font(Tokens.sans(12.5))
                        .foregroundStyle(Tokens.text3)
                }
                .padding(.horizontal, 60)
            }
            .frame(maxHeight: .infinity)
            .clipped()

            OnboardingFooter(page: 2, back: back) {
                HStack(spacing: 16) {
                    if !allGranted {
                        Button(action: next) {
                            Text(L("Настроить позже"))
                                .font(Tokens.sans(12))
                                .foregroundStyle(Tokens.text3)
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                        OnboardingDisabledPill(title: L("Далее"))
                    } else {
                        OnboardingPillButton(L("Далее"), variant: .primary, action: next)
                    }
                }
            }
        }
        .onReceive(timer) { _ in refresh() }
    }

    private func refresh() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        axGranted = AXIsProcessTrusted()
    }

    // MARK: Карточка

    private func permissionCard(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> some View
    ) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.sans(15, weight: .medium))
                    .foregroundStyle(Tokens.text)
                Text(subtitle)
                    .font(Tokens.sans(13))
                    .foregroundStyle(Tokens.text2)
            }
            Spacer(minLength: 0)
            control()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(Tokens.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.border, lineWidth: 1))
    }

    // MARK: Микрофон

    @ViewBuilder
    private var micControl: some View {
        switch micStatus {
        case .authorized:
            grantedBadge
        case .notDetermined:
            if micRequesting {
                requestingIndicator
            } else {
                OnboardingPillButton(L("Разрешить")) {
                    micRequesting = true
                    Task {
                        _ = await AVCaptureDevice.requestAccess(for: .audio)
                        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                        micRequesting = false
                    }
                }
            }
        default:
            // Отклонено: системный запрос больше не покажется — только настройки.
            OnboardingPillButton(L("Открыть настройки")) {
                openSystemSettings("Privacy_Microphone")
            }
        }
    }

    // MARK: Универсальный доступ

    @ViewBuilder
    private var axControl: some View {
        if axGranted {
            grantedBadge
        } else if axRequested {
            requestingIndicator
        } else {
            OnboardingPillButton(L("Разрешить")) {
                let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
                openSystemSettings("Privacy_Accessibility")
                axRequested = true
            }
        }
    }

    // MARK: Состояния

    private var grantedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Tokens.success)
            Text(L("Разрешено"))
                .font(Tokens.sans(12.5, weight: .medium))
        }
        .foregroundStyle(Tokens.successDeep)
        .padding(.horizontal, 13)
        .frame(height: 30)
        .background(Tokens.successSoft, in: Capsule())
    }

    private var requestingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(L("Запрос…"))
                .font(Tokens.sans(12.5))
                .foregroundStyle(Tokens.text3)
        }
    }

    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
