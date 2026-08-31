import SwiftUI

/// The card surface every screen is built from — white fill, soft border, one of
/// two radii. Written by hand in eight places before this existed, which is how
/// 16 and 18 started showing up on the same screen by accident.
///
/// The two styles are a real distinction, not a preference: `plain` is a card
/// sitting on the tab background, `nested` is a block inside another card or a
/// secondary group, and it is a shade warmer and a notch tighter.
struct DSCardStyle {
    let fill: Color
    let radius: CGFloat

    /// Top-level card on a tab: white, radius 18.
    static var plain: DSCardStyle {
        DSCardStyle(fill: Tokens.surface, radius: Tokens.radiusCard)
    }

    /// A block inside a card, or a secondary group: tinted, radius 16.
    static var nested: DSCardStyle {
        DSCardStyle(fill: Tokens.surfaceSoft, radius: Tokens.radiusCardNested)
    }

    /// White fill at the nested radius — a standalone block that still reads as
    /// a card rather than a section (the module setting preview, for one).
    static var compact: DSCardStyle {
        DSCardStyle(fill: Tokens.surface, radius: Tokens.radiusCardNested)
    }
}

extension View {
    /// Card fill and border. Padding stays at the call site: cards hold
    /// everything from a chart to a single row, and one padding can't fit both.
    func dsCard(_ style: DSCardStyle = .plain) -> some View {
        background(style.fill, in: RoundedRectangle(cornerRadius: style.radius))
            .overlay(
                RoundedRectangle(cornerRadius: style.radius)
                    .stroke(Tokens.cardBorder, lineWidth: 1)
            )
    }
}

/// A card with a header: title on the left, caption on the right, content below.
/// `muted` greys both out — an empty chart shouldn't shout its title.
struct DSCard<Content: View>: View {
    let title: String
    var caption: String = ""
    var muted = false
    var style: DSCardStyle = .plain
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title)
                    .font(Tokens.sans(15, weight: .medium))
                    .foregroundStyle(muted ? Tokens.text3 : Tokens.text)
                Spacer(minLength: 16)
                Text(caption)
                    .font(Tokens.sans(12.5))
                    .foregroundStyle(muted ? Tokens.controlBorder : Tokens.text3)
            }
            content
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(style)
    }
}
