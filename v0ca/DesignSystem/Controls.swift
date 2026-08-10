import SwiftUI

/// Toggle per the "Settings · New screens" mockup: 44×26 track, white 20px knob
/// with shadow, travel 3→21px, 0.18s animation.
struct AccentToggle: View {
    @Binding var isOn: Bool
    /// A disabled toggle ignores clicks and is shown dimmed.
    var enabled: Bool = true

    var body: some View {
        Button {
            guard enabled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isOn ? Tokens.accent : Tokens.cardBorder)
                    .frame(width: 44, height: 26)
                Circle()
                    .fill(Tokens.knob)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .offset(x: isOn ? 21 : 3)
            }
            .opacity(enabled ? 1 : 0.45)
        }
        .pointerCursor(active: enabled)
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
    }
}

/// Tab-style switcher: gray capsule track, active segment is a white pill with shadow.
/// For choosing between 2–3 equal options where a dropdown would be overkill.
struct DSSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Tokens.surface2, in: Capsule())
    }

    private func segment(_ option: (value: Value, label: String)) -> some View {
        let isSelected = option.value == selection
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = option.value
            }
        } label: {
            Text(option.label)
                .font(Tokens.sans(13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Tokens.text : Tokens.text3)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 30)
                .background {
                    if isSelected {
                        // raised: in dark theme the active segment is lighter than
                        // the track, not darker (surface is darker than surface2 there).
                        Capsule()
                            .fill(Tokens.raised)
                            .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Radio circle (model catalog): selected — thick 5.5 accent ring,
/// otherwise a thin gray 1.5 one. Not clickable itself — the row handles the click.
struct DSRadio: View {
    let selected: Bool

    var body: some View {
        Circle()
            .strokeBorder(
                selected ? Tokens.accent : Tokens.controlBorderHover,
                lineWidth: selected ? 5.5 : 1.5
            )
            .frame(width: 18, height: 18)
    }
}
