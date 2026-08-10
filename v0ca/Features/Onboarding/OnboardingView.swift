import SwiftUI

/// Контейнер онбординга: тайтлбар 44px, контент, футер 64px — как в макете.
/// Каждый экран сам собирает свой футер через `OnboardingFooter` (состояние
/// кнопки «Далее» зависит от экрана — например, от выданных разрешений).
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case intro
        case powerFree
        case permissions
        case modelIntro
        case models
        case shortcutIntro
        case shortcuts
        case done
    }

    @State private var step: Step
    let models: ModelManager
    let close: () -> Void

    /// `step` — стартовый экран; кроме обычного запуска используется
    /// отладочным рендером скриншотов (OnboardingScreenshots).
    init(models: ModelManager, step: Step = .intro, close: @escaping () -> Void) {
        self.models = models
        self.close = close
        _step = State(initialValue: step)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.surface)
        .ignoresSafeArea()
    }

    private var titleBar: some View {
        WindowTitleBar()
    }

    @ViewBuilder
    private var screen: some View {
        switch step {
        case .intro:
            OnboardingIntroScreen { advance() }
        case .powerFree:
            OnboardingPowerFreeScreen(back: { back() }, next: { advance() })
        case .permissions:
            OnboardingPermissionsScreen(back: { back() }, next: { advance() })
        case .modelIntro:
            OnboardingModelIntroScreen(back: { back() }, next: { advance() })
        case .models:
            OnboardingModelsScreen(models: models, back: { back() }, next: { advance() })
        case .shortcutIntro:
            OnboardingShortcutIntroScreen(back: { back() }, next: { advance() })
        case .shortcuts:
            OnboardingShortcutsScreen(back: { back() }, next: { advance() })
        case .done:
            OnboardingFinalScreen { finish() }
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.2)) { step = next }
        } else {
            finish()
        }
    }

    /// «Готово» на финальном экране: помечаем онбординг пройденным (снимает
    /// блокировку записи, скрывает старую вкладку и автопоказ при запуске),
    /// греем выбранную модель — к первому хоткею она уже в памяти — и закрываем окно.
    private func finish() {
        UserDefaults.standard.set(true, forKey: Prefs.Key.onboardingDone)
        Task { await models.ensureLoaded() }
        close()
    }

    private func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.easeInOut(duration: 0.2)) { step = prev }
        }
    }
}

// MARK: - Градиент шапки

/// Фоновый градиент верхней части экрана: три размытых радиальных пятна
/// (слева, по центру, справа) с опциональным белым затуханием вниз.
struct OnboardingGradient: View {
    let left: Color
    let center: Color
    let right: Color
    var height: CGFloat = 400
    /// Доли высоты, между которыми фон уходит в белый; nil — без затухания
    /// (экран сам перекрывает низ белым блоком).
    var fade: (from: CGFloat, to: CGFloat)?

    /// Основной способ создания — по пресету из HeaderGradients.
    init(_ preset: HeaderGradient.Triple, height: CGFloat = 400, fade: (from: CGFloat, to: CGFloat)?) {
        left = preset.left
        center = preset.center
        right = preset.right
        self.height = height
        self.fade = fade
    }

    var body: some View {
        // Без .blur: радиальные градиенты и так плавные, а блюр сэмплирует
        // за краями вью и оставляет грязные полосы-артефакты по периметру.
        ZStack {
            spot(center, at: UnitPoint(x: 0.5, y: 0), radius: 0.68)
            spot(right, at: UnitPoint(x: 0.88, y: 0.02), radius: 0.6)
            spot(left, at: UnitPoint(x: 0.12, y: 0), radius: 0.62)
        }
        .overlay {
            if let fade {
                LinearGradient(
                    stops: [
                        .init(color: Tokens.surface.opacity(0), location: fade.from),
                        .init(color: Tokens.surface, location: fade.to),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .frame(height: height)
        .clipped()
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func spot(_ color: Color, at point: UnitPoint, radius: CGFloat) -> some View {
        EllipticalGradient(
            stops: [.init(color: color, location: 0), .init(color: color.opacity(0), location: 1)],
            center: point,
            startRadiusFraction: 0,
            endRadiusFraction: radius
        )
    }
}

// MARK: - Футер

/// Нижняя полоса 64px: «Назад» слева, точки прогресса по центру, действия справа.
/// Без `page` и `back` (интро, финал) — единственная кнопка по центру.
struct OnboardingFooter<Trailing: View>: View {
    /// Активная точка прогресса (0-based из `pages`); nil — точки не показываются.
    var page: Int?
    var pages: Int = 5
    var back: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            if page == nil, back == nil {
                trailing()
            } else {
                HStack {
                    if let back {
                        OnboardingPillButton(L("Назад"), variant: .ghost, action: back) {
                            Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        }
                    }
                    Spacer()
                    trailing()
                }
                if let page {
                    dots(active: page)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Divider().overlay(Tokens.surface2)
        }
    }

    private func dots(active: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<pages, id: \.self) { index in
                Capsule()
                    .fill(index < active ? Tokens.accentSoftHover
                        : index == active ? Tokens.accent
                        : Tokens.border)
                    .frame(width: index == active ? 20 : 6, height: 6)
            }
        }
    }
}

// MARK: - Кнопка-пилюля

/// Кнопки онбординга — капсулы (радиус 100 в макете), в отличие от радиуса 8
/// у DSButton в настройках. Логика вариантов и ховера повторяет DSButton.
struct OnboardingPillButton<Icon: View>: View {
    let title: String
    var variant: DSButtonVariant = .secondary
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon

    @State private var hovering = false

    init(_ title: String, variant: DSButtonVariant = .secondary,
         action: @escaping () -> Void, @ViewBuilder icon: @escaping () -> Icon) {
        self.title = title
        self.variant = variant
        self.action = action
        self.icon = icon
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                icon()
                Text(title)
            }
            .font(Tokens.sans(13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, variant == .ghost ? 14 : 20)
            .frame(height: 36)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(variant == .secondary ? borderColor : .clear, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
    }

    private var background: Color {
        switch variant {
        case .primary: hovering ? Tokens.accentHover : Tokens.accent
        case .ghost: hovering ? Tokens.surface2 : .clear
        default: hovering ? Tokens.background : Tokens.surface
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: Tokens.textOnAccent
        case .ghost: hovering ? Tokens.text : Tokens.text3
        default: Tokens.text
        }
    }

    private var borderColor: Color { hovering ? Tokens.text3.opacity(0.5) : Tokens.controlBorder }
}

extension OnboardingPillButton where Icon == EmptyView {
    init(_ title: String, variant: DSButtonVariant = .secondary, action: @escaping () -> Void) {
        self.init(title, variant: variant, action: action) { EmptyView() }
    }
}

/// Неактивная «Далее»: серый текст на сером фоне, клик игнорируется (макет 02A).
struct OnboardingDisabledPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Tokens.sans(13, weight: .medium))
            .foregroundStyle(Tokens.text3.opacity(0.75))
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(Tokens.surface2, in: Capsule())
    }
}
