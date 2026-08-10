import SwiftUI

/// Onboarding container: 44px title bar, content, 64px footer — as in the mockup.
/// Each screen builds its own footer via `OnboardingFooter` (the "Next" button's
/// state depends on the screen — e.g. on granted permissions).
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

    /// `step` is the starting screen; besides the normal launch it's used by the
    /// debug screenshot renderer (OnboardingScreenshots).
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

    /// "Done" on the final screen: mark onboarding as complete (unblocks recording,
    /// hides the old tab and the auto-show on launch), warm up the selected model —
    /// it's already in memory by the first hotkey — and close the window.
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

// MARK: - Header gradient

/// Background gradient of the screen's top area: three blurred radial spots
/// (left, center, right) with an optional white fade toward the bottom.
struct OnboardingGradient: View {
    let left: Color
    let center: Color
    let right: Color
    var height: CGFloat = 400
    /// Height fractions between which the background fades to white; nil — no fade
    /// (the screen covers the bottom with a white block itself).
    var fade: (from: CGFloat, to: CGFloat)?

    /// Primary way to create one — from a HeaderGradients preset.
    init(_ preset: HeaderGradient.Triple, height: CGFloat = 400, fade: (from: CGFloat, to: CGFloat)?) {
        left = preset.left
        center = preset.center
        right = preset.right
        self.height = height
        self.fade = fade
    }

    var body: some View {
        // No .blur: the radial gradients are already smooth, and blur samples
        // beyond the view edges, leaving dirty band artifacts around the perimeter.
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

// MARK: - Footer

/// 64px bottom bar: "Back" on the left, progress dots in the center, actions on
/// the right. Without `page` and `back` (intro, final) — a single centered button.
struct OnboardingFooter<Trailing: View>: View {
    /// Active progress dot (0-based out of `pages`); nil — dots are hidden.
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

// MARK: - Pill button

/// Onboarding buttons are capsules (radius 100 in the mockup), unlike the radius-8
/// DSButton in settings. Variant and hover logic mirrors DSButton.
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

/// Disabled "Next": gray text on a gray background, clicks are ignored (mockup 02A).
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
