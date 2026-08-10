import SwiftUI

/// Thin title bar strip behind the system traffic lights: no title,
/// 32pt tall — the window buttons sit with equal top and bottom margins.
/// Used by the settings and onboarding windows (the system title bar is transparent).
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
