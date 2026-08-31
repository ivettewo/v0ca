import SwiftUI

/// Settings window per the "Settings · New screens" mockup, "Window frame" card:
/// 34px title bar (traffic lights only), 198px sidebar on the shared background,
/// content is a white panel "glued" to the right/bottom edges with only the
/// top-left corner rounded. Logo with version sits at the bottom of the sidebar.
struct SettingsRootView: View {
    let coordinator: RecordingCoordinator

    enum Tab: String, CaseIterable {
        case dictation = "Диктовка"
        case general = "Общие"
        case modules = "Модули"
        case models = "Модели"
        case providers = "Провайдеры"
        case sound = "Звук"
        case history = "История"
        case permissions = "Разрешения"
        case stats = "Статистика"

        var icon: String {
            switch self {
            case .dictation: "mic"
            case .general: "gearshape"
            case .modules: "square.grid.2x2"
            case .models: "cpu"
            case .providers: "key"
            case .sound: "speaker.wave.2"
            case .history: "clock.arrow.circlepath"
            case .permissions: "checkmark.shield"
            case .stats: "chart.bar"
            }
        }

        /// The tab draws the whole content sheet itself: no shared scroll view,
        /// no padding and no header gradient. Modules need it — the split has a
        /// column of its own that has to reach the edges.
        var isFullBleed: Bool { self == .modules }
    }

    @Bindable var router: SettingsRouter

    private var tab: Tab { router.tab }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar: empty 34px for the traffic lights, no divider —
            // the lights sit on the shared window background.
            Color.clear.frame(height: 34)
            HStack(spacing: 0) {
                sidebar
                contentPanel
            }
        }
        // Fill the whole hosting view and ignore the title bar safe area: otherwise
        // .fullSizeContentView adds an empty strip on top the height of the title bar.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.background)
        .ignoresSafeArea()
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            tabButton(.dictation)

            // Divider between "Dictation" and the rest of the tabs.
            Rectangle()
                .fill(Tokens.border)
                .frame(height: 1)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)

            ForEach(Tab.allCases.filter { $0 != .dictation && $0 != .stats }, id: \.self) { item in
                tabButton(item)
            }

            Spacer()

            // Stats sit apart from the settings tabs, pinned to the bottom of the
            // sidebar as in the mockup.
            tabButton(.stats)
                .padding(.bottom, 8)

            // Logo and version at the bottom, on a shared baseline.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 0) {
                    Text("v0ca").foregroundStyle(Tokens.text)
                    Text(".").foregroundStyle(Tokens.brand)
                }
                .font(Tokens.logo(16))
                .kerning(-0.64)
                Text("1.0.0")
                    .font(Tokens.mono(11))
                    .foregroundStyle(Tokens.text3)
            }
            .padding(.horizontal, 11)
            .padding(.bottom, 2)
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .frame(width: 198)
    }

    private func tabButton(_ item: Tab) -> some View {
        let active = tab == item
        return Button {
            router.tab = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .frame(width: 17)
                Text(L(item.rawValue))
                    .font(Tokens.sans(13.5, weight: active ? .medium : .regular))
                Spacer()
            }
            .foregroundStyle(active ? Tokens.accentHover : Tokens.text)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(active ? Tokens.surface : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    // MARK: - Content

    /// White content "sheet": border on top and left, only the top-left corner
    /// rounded; right and bottom edges run into the window edge. On top sits a
    /// fixed per-tab gradient (content scrolls over it, as in the mockup).
    private var contentPanel: some View {
        ZStack(alignment: .top) {
            tabGradient
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.surface, in: UnevenRoundedRectangle(topLeadingRadius: 18))
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 18)
                    .stroke(Tokens.border, lineWidth: 1)
                    // Push the right and bottom edges past the window edge.
                    .padding(.trailing, -1)
                    .padding(.bottom, -1)
            )
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18))
    }

    /// Per-tab header gradients from the "Settings · New screens" mockup
    /// (Models gets a linear blue-gray one, like the onboarding models step).
    @ViewBuilder
    private var tabGradient: some View {
        switch tab {
        case .modules:
            // Deliberately none: the gradient would run under the list column
            // and stain its background. The mockup has no gradient here either.
            EmptyView()
        case .dictation:
            OnboardingGradient(
                HeaderGradient.shortcuts,
                height: 380, fade: (from: 0.22, to: 0.66)
            )
        case .general:
            OnboardingGradient(
                HeaderGradient.intro,
                height: 420, fade: (from: 0.18, to: 0.62)
            )
        case .models:
            LinearGradient(
                colors: [HeaderGradient.modelsLinear.start, HeaderGradient.modelsLinear.end],
                startPoint: .leading, endPoint: .trailing
            )
            .opacity(0.38)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(height: 220)
            .allowsHitTesting(false)
        case .sound, .permissions:
            OnboardingGradient(
                HeaderGradient.permissions,
                height: 400, fade: (from: 0.16, to: 0.6)
            )
        case .providers:
            OnboardingGradient(
                HeaderGradient.providers,
                height: 400, fade: (from: 0.14, to: 0.58)
            )
        case .history:
            OnboardingGradient(
                HeaderGradient.modelIntro,
                height: 400, fade: (from: 0.16, to: 0.6)
            )
        case .stats:
            OnboardingGradient(
                HeaderGradient.stats,
                height: 400, fade: (from: 0.18, to: 0.62)
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if tab.isFullBleed {
            switch tab {
            case .modules: ModulesTab()
            default: EmptyView()
            }
        } else {
            scrollingContent
        }
    }

    @ViewBuilder
    private var scrollingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switch tab {
                case .dictation: DictationTab(coordinator: coordinator)
                case .general: GeneralTab(coordinator: coordinator)
                case .models: ModelsTab(models: coordinator.models)
                case .sound: SoundTab()
                case .history: HistoryTab(coordinator: coordinator)
                case .permissions: PermissionsTab()
                case .providers: ProvidersTab(keys: coordinator.providerKeys)
                case .stats: StatsTab(coordinator: coordinator)
                // Full-bleed tabs are drawn above, outside this container.
                case .modules: EmptyView()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Clicking empty space / a label dismisses text field focus.
            // The background layer only catches "pass-through" clicks and doesn't block buttons.
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NotificationCenter.default.post(name: .dismissFieldFocus, object: nil)
                    }
            )
        }
    }
}

extension Notification.Name {
    /// Dismiss focus from settings text fields (click outside a field).
    static let dismissFieldFocus = Notification.Name("v0ca.dismissFieldFocus")
}
