import SwiftUI

/// Capsule chip (model cards: "Active", "Recommended"): 11/500, 20pt tall.
struct DSChip: View {
    let text: String
    var background: Color = Tokens.surface2
    var foreground: Color = Tokens.text2

    init(_ text: String, background: Color = Tokens.surface2, foreground: Color = Tokens.text2) {
        self.text = text
        self.background = background
        self.foreground = foreground
    }

    var body: some View {
        Text(text)
            .font(Tokens.sans(11, weight: .medium))
            .foregroundStyle(foreground)
            .frame(height: 20)
            .padding(.horizontal, 8)
            .background(background, in: Capsule())
    }
}

/// Progress bar: capsule track filled from the left. One component for all uses —
/// model accuracy/speed, history player, mic level (gradient).
/// Animation is applied at the call site via `.animation(_:value:)`.
struct DSProgressBar: View {
    /// Fill fraction 0…1 (clamped to the range).
    let fraction: CGFloat
    var height: CGFloat = 5
    var track: Color = Tokens.surface2
    var fill: AnyShapeStyle = AnyShapeStyle(Tokens.accent)

    var body: some View {
        Capsule()
            .fill(track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(fill)
                        .frame(width: geometry.size.width * min(max(fraction, 0), 1))
                }
            }
            .clipShape(Capsule())
    }
}
