import SwiftUI

/// Окно настроек по макету «Экран · Настройки»: топ-бар 44px, сайдбар 208px, контент.
struct SettingsRootView: View {
    let coordinator: RecordingCoordinator

    enum Tab: String, CaseIterable {
        case onboarding = "Онбординг"
        case general = "Общие"
        case models = "Модели"
        case sound = "Звук"
        case history = "История"
        case permissions = "Разрешения"

        var icon: String {
            switch self {
            case .onboarding: "sparkles"
            case .general: "gearshape"
            case .models: "square.stack.3d.up"
            case .sound: "mic"
            case .history: "clock.arrow.circlepath"
            case .permissions: "lock.shield"
            }
        }
    }

    @Bindable var router: SettingsRouter
    @AppStorage(Prefs.Key.onboardingDone) private var onboardingDone = false

    /// «Онбординг» показывается только пока не завершён.
    private var visibleTabs: [Tab] {
        onboardingDone ? Tab.allCases.filter { $0 != .onboarding } : Tab.allCases
    }

    private var tab: Tab { router.tab }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Tokens.background)
        }
        // Заполняем весь хостинг-вью и игнорируем safe-area тайтлбара: иначе
        // .fullSizeContentView добавляет сверху пустую полосу в высоту тайтлбара.
        // Отступ под traffic lights делаем сами (padding логотипа/контента).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.background)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Логотип: моноширинный 20/600, точка всегда акцентная.
            // Отступ сверху — под системные кнопки окна (traffic lights).
            HStack(spacing: 0) {
                Text("v0ca").foregroundStyle(Tokens.text)
                Text(".").foregroundStyle(Tokens.accent)
            }
            .font(Tokens.mono(20, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(visibleTabs, id: \.self) { item in
                    tabButton(item)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("v 1.0.0")
                .font(Tokens.mono(11))
                .foregroundStyle(Tokens.text3)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(width: 208)
        .background(Tokens.background)
        .overlay(alignment: .trailing) {
            Divider().overlay(Tokens.border.opacity(0.7))
        }
    }

    private func tabButton(_ item: Tab) -> some View {
        Button {
            router.tab = item
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .frame(width: 17)
                Text(L(item.rawValue))
                    .font(Tokens.sans(13.5, weight: tab == item ? .medium : .regular))
                Spacer()
            }
            .foregroundStyle(tab == item ? Tokens.text : Tokens.text2)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                tab == item ? Tokens.surface2 : .clear,
                in: RoundedRectangle(cornerRadius: Tokens.radiusControl)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusControl))
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch tab {
                case .onboarding: OnboardingTab(models: coordinator.models, router: router)
                case .general: GeneralTab(coordinator: coordinator)
                case .models: ModelsTab(models: coordinator.models)
                case .sound: SoundTab()
                case .history: HistoryTab(coordinator: coordinator)
                case .permissions: PermissionsTab()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 24)
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
