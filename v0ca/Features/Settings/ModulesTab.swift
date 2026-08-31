import SwiftUI

/// "Modules" tab per the "Settings · Modules — variants" mockup, variant 1c:
/// the list of modules on the left, the selected one on the right. An accent
/// border marks the modules that are on, a white row is the one being read.
///
/// The only full-bleed tab: the split runs to the edges of the content sheet,
/// so it renders outside the shared scroll container (see `Tab.isFullBleed`).
/// The switch writes `module.<id>.enabled` and nothing else — wiring modules to
/// what they actually do comes later.
struct ModulesTab: View {
    @State private var selection: String = ModuleCatalog.all.first?.id ?? ""

    private static let listWidth: CGFloat = 230

    var body: some View {
        HStack(spacing: 0) {
            list
            panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - List

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("\(L("Модули")) · \(ModuleCatalog.all.count)")
                .padding(.leading, 6)
                .padding(.bottom, 2)

            ForEach(ModuleCatalog.all) { module in
                ModuleRow(
                    module: module,
                    selected: module.id == selection,
                    onSelect: { selection = module.id }
                )
            }

            Spacer(minLength: 16)

            Text(L("Все модули идут с приложением — скачивать нечего."))
                .font(Tokens.sans(11.5))
                .lineSpacing(4)
                .foregroundStyle(Tokens.text3)
                .padding(.horizontal, 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(width: Self.listWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity)
        // The gradient belongs to the list alone: the panel next to it is a page
        // of text, and a wash behind it would only fight the words.
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Tokens.surfaceSoft
                // The same neutral blue-gray wash the Models tab uses: this
                // screen is a list of parts, not a mood.
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
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Tokens.surface2)
                .frame(width: 1)
        }
    }

    // MARK: - Panel

    @ViewBuilder
    private var panel: some View {
        if let module = ModuleCatalog.all.first(where: { $0.id == selection }) {
            ModulePanel(module: module)
        } else {
            Color.clear
        }
    }
}

// MARK: - Row

/// One line in the list. Owns its own switch state: `@AppStorage` keeps every
/// view of the same key in sync, so the row and the panel toggle can't disagree.
private struct ModuleRow: View {
    let module: ModuleInfo
    let selected: Bool
    let onSelect: () -> Void

    @AppStorage private var enabled: Bool

    init(module: ModuleInfo, selected: Bool, onSelect: @escaping () -> Void) {
        self.module = module
        self.selected = selected
        self.onSelect = onSelect
        _enabled = AppStorage(wrappedValue: false, module.defaultsKey)
    }

    var body: some View {
        Button(action: onSelect) {
            Text(L(module.title))
                .font(Tokens.sans(13.5, weight: .medium))
                .foregroundStyle(enabled ? Tokens.text : Tokens.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(selected ? Tokens.surface : .clear, in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        // Inset by half the width: a centered stroke straddles the
                        // edge and reads heavier than it is.
                        .inset(by: 0.5)
                        .stroke(border, lineWidth: 1)
                )
                .shadow(
                    color: Tokens.shadowCard.opacity(selected ? 0.06 : 0),
                    radius: 5, y: 2
                )
                .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    /// The accent border is what "on" looks like; a row that is merely open
    /// gets the quiet card border instead.
    private var border: Color {
        if enabled { return Tokens.accent }
        return selected ? Tokens.cardBorder : .clear
    }
}

// MARK: - Panel

private struct ModulePanel: View {
    let module: ModuleInfo

    @AppStorage private var enabled: Bool

    init(module: ModuleInfo) {
        self.module = module
        _enabled = AppStorage(wrappedValue: false, module.defaultsKey)
    }

    /// Body text width from the mockup — long paragraphs stop being readable
    /// well before the panel runs out of room.
    private static let textWidth: CGFloat = 520

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Rectangle()
                    .fill(Tokens.surface2)
                    .frame(height: 1)
                body(for: module)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: module.icon)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Tokens.text2)
                .frame(width: 46, height: 46)
                .background(Tokens.surface2, in: RoundedRectangle(cornerRadius: 14))
                .opacity(enabled ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 5) {
                Text(L(module.title))
                    .font(Tokens.sans(20, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundStyle(enabled ? Tokens.text : Tokens.text3)
                Text(L(module.tagline))
                    .font(Tokens.sans(13))
                    .foregroundStyle(Tokens.text3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 1)

            AccentToggle(isOn: $enabled)
                .padding(.top, 10)
        }
    }

    private func body(for module: ModuleInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(module.body.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    paragraph(text)
                case .bullets(let items):
                    bullets(items)
                case .link(let title, let url):
                    linkRow(title: title, url: url)
                case .settingPreview(let location, let title, let subtitle):
                    settingPreview(location: location, title: title, subtitle: subtitle)
                case .formPreview(let location, let title, let placeholder, let action):
                    formPreview(
                        location: location, title: title,
                        placeholder: placeholder, action: action
                    )
                }
            }
        }
        .frame(maxWidth: Self.textWidth, alignment: .leading)
    }

    private func bullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Tokens.text3)
                        .frame(width: 4, height: 4)
                        // Sits on the first line's optical centre.
                        .padding(.top, 8)
                    Text(L(item))
                        .font(Tokens.sans(13.5))
                        .lineSpacing(5)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// What the module adds elsewhere, drawn as the real row it will be. Inert
    /// on purpose: this is a picture of a setting, not the setting — flipping it
    /// here would leave two places claiming to own the same switch.
    private func settingPreview(location: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingRow(title: L(title), subtitle: L(subtitle)) {
                AccentToggle(isOn: .constant(true), enabled: false)
            }
            .padding(.horizontal, 20)
            .dsCard(.compact)
            .allowsHitTesting(false)

            Text(L(location))
                .font(Tokens.mono(11))
                .foregroundStyle(Tokens.text3)
                .padding(.leading, 4)
        }
    }

    /// The connect card a provider module adds, drawn as it will look: name,
    /// key field, button. Inert, like `settingPreview`.
    private func formPreview(
        location: String,
        title: String,
        placeholder: String,
        action: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(Tokens.sans(15, weight: .medium))
                    .foregroundStyle(Tokens.text)

                HStack(spacing: 8) {
                    Text(L(placeholder))
                        .font(Tokens.mono(13))
                        .foregroundStyle(Tokens.text3)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Tokens.surface, in: Capsule())
                        .overlay(Capsule().stroke(Tokens.controlBorder, lineWidth: 1))

                    Text(L(action))
                        .font(Tokens.sans(13, weight: .medium))
                        .foregroundStyle(Tokens.surface)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(Tokens.text, in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .dsCard(.nested)
            .allowsHitTesting(false)

            Text(L(location))
                .font(Tokens.mono(11))
                .foregroundStyle(Tokens.text3)
                .padding(.leading, 4)
        }
    }

    /// The module's own page on the web. Opens in the browser — nothing about a
    /// module is worth an in-app browser.
    private func linkRow(title: String, url: String) -> some View {
        Button {
            guard let address = URL(string: url) else { return }
            NSWorkspace.shared.open(address)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(Tokens.sans(13.5, weight: .medium))
            }
            .foregroundStyle(Tokens.accentHover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private func paragraph(_ text: String) -> some View {
        Text(L(text))
            .font(Tokens.sans(13.5))
            .lineSpacing(6)
            .foregroundStyle(Tokens.text2)
            .fixedSize(horizontal: false, vertical: true)
    }

}
