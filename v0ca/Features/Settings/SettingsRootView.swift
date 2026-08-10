import SwiftUI

/// Окно настроек по макету «Настройки · Новые экраны», карточка «Каркас окна»:
/// тайтлбар 34px (только traffic lights), сайдбар 198px на общем фоне, контент —
/// белая панель, «приклеенная» к правому/нижнему краю, со скруглением только
/// верхнего левого угла. Логотип с версией — внизу сайдбара.
struct SettingsRootView: View {
    let coordinator: RecordingCoordinator
    /// Открыть окно нового онбординга (кнопка внизу сайдбара).
    let openOnboarding: () -> Void

    enum Tab: String, CaseIterable {
        case dictation = "Диктовка"
        case general = "Общие"
        case models = "Модели"
        case sound = "Звук"
        case history = "История"
        case permissions = "Разрешения"

        var icon: String {
            switch self {
            case .dictation: "mic"
            case .general: "gearshape"
            case .models: "cpu"
            case .sound: "speaker.wave.2"
            case .history: "clock.arrow.circlepath"
            case .permissions: "checkmark.shield"
            }
        }
    }

    @Bindable var router: SettingsRouter

    private var tab: Tab { router.tab }

    var body: some View {
        VStack(spacing: 0) {
            // Тайтлбар: пустые 34px под traffic lights, без разделителя —
            // светофоры лежат на общем фоне окна.
            Color.clear.frame(height: 34)
            HStack(spacing: 0) {
                sidebar
                contentPanel
            }
        }
        // Заполняем весь хостинг-вью и игнорируем safe-area тайтлбара: иначе
        // .fullSizeContentView добавляет сверху пустую полосу в высоту тайтлбара.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.background)
        .ignoresSafeArea()
    }

    // MARK: - Сайдбар

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            tabButton(.dictation)

            // Разделитель между «Диктовкой» и остальными вкладками.
            Rectangle()
                .fill(Tokens.border)
                .frame(height: 1)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)

            ForEach(Tab.allCases.filter { $0 != .dictation }, id: \.self) { item in
                tabButton(item)
            }

            Spacer()

            // Временная кнопка на период разработки нового онбординга.
            newOnboardingButton
                .padding(.bottom, 8)

            // Логотип и версия — внизу, на одной базовой линии.
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

    private var newOnboardingButton: some View {
        Button(action: openOnboarding) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13))
                    .frame(width: 17)
                Text(L("Новый онбординг"))
                    .font(Tokens.sans(13.5))
                Spacer()
            }
            .foregroundStyle(Tokens.text2)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .hoverBackground(Tokens.surface2, radius: 9)
        .pointerCursor()
    }

    // MARK: - Контент

    /// Белая «простыня» контента: рамка сверху и слева, скруглён только верхний
    /// левый угол; правый и нижний край уходят в край окна. Сверху — фиксированный
    /// градиент вкладки (контент скроллится поверх него, как в макете).
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
                    // Правую и нижнюю кромки уводим за край окна.
                    .padding(.trailing, -1)
                    .padding(.bottom, -1)
            )
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18))
    }

    /// Градиенты шапок по вкладкам из макета «Настройки · Новые экраны»
    /// (у «Моделей» — линейный сине-серый, как на шаге моделей онбординга).
    @ViewBuilder
    private var tabGradient: some View {
        switch tab {
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
        case .history:
            OnboardingGradient(
                HeaderGradient.modelIntro,
                height: 400, fade: (from: 0.16, to: 0.6)
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switch tab {
                case .dictation: DictationTab(coordinator: coordinator)
                case .general: GeneralTab(coordinator: coordinator)
                case .models: ModelsTab(models: coordinator.models)
                case .sound: SoundTab()
                case .history: HistoryTab(coordinator: coordinator)
                case .permissions: PermissionsTab()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Клик по пустому месту / подписи снимает фокус с текстовых полей.
            // Фоновый слой ловит только «сквозные» клики и не мешает кнопкам.
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
    /// Сбросить фокус с текстовых полей настроек (клик вне поля).
    static let dismissFieldFocus = Notification.Name("v0ca.dismissFieldFocus")
}
