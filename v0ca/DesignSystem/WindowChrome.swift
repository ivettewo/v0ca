import SwiftUI

/// Тонкая полоса тайтлбара под системные traffic lights: без заголовка,
/// высота 32 — кнопки окна стоят с равными отступами сверху и снизу.
/// Используется окнами настроек и онбординга (системный тайтлбар прозрачный).
struct WindowTitleBar: View {
    var body: some View {
        Tokens.surfaceSoft
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                Divider().overlay(Tokens.border.opacity(0.7))
            }
    }
}
