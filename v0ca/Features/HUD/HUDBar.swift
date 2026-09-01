import AppKit
import KeyboardShortcuts
import SwiftUI

/// Shared state of the always-visible bar. The panel controller owns hover
/// (it comes from an AppKit tracking area), the view owns the open menu;
/// both need to be known in both places, hence one small observable object.
@MainActor
@Observable
final class HUDBarState {
    private(set) var hovered = false
    private(set) var menuOpen = false

    /// The panel is only as big as the strip while it sits idle — a full-size
    /// panel would swallow clicks across the bottom of the screen. The controller
    /// resizes it when this flips.
    var expanded: Bool { hovered || menuOpen }

    @ObservationIgnored var onExpandedChange: (() -> Void)?

    func setHovered(_ value: Bool) {
        guard hovered != value else { return }
        hovered = value
        if !value {
            menuOpen = false
        }
        onExpandedChange?()
    }

    func setMenuOpen(_ value: Bool) {
        guard menuOpen != value else { return }
        menuOpen = value
        onExpandedChange?()
    }

    /// Must stay a no-op when there is nothing to reset: the panel controller calls
    /// this from its layout pass, and an unconditional callback would bounce
    /// straight back into that pass forever.
    func reset() {
        guard hovered || menuOpen else { return }
        hovered = false
        menuOpen = false
        onExpandedChange?()
    }
}

/// Tracking-area host: reports hover for the whole panel. `.activeAlways` is
/// required — the panel never becomes key, so the default `.activeInKeyWindow`
/// would never fire.
final class HUDHoverView: NSView {
    var onHover: ((Bool) -> Void)?

    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }
}

/// Quick menu capsule: language · microphone · mode. Same 38pt height as the
/// recording capsule — the mockup draws it at 32, but the bar has to live inside
/// the existing HUD flow, so all capsules share one height.
struct HUDQuickMenu: View {
    let coordinator: RecordingCoordinator
    let bar: HUDBarState

    @AppStorage(Prefs.Key.recognitionLanguage) private var language: String = "auto"
    @AppStorage(Prefs.Key.hudMode) private var mode: String = Prefs.HUDMode.dictation.rawValue

    private var selectedMode: Prefs.HUDMode {
        Prefs.HUDMode(rawValue: mode) ?? .dictation
    }

    var body: some View {
        HStack(spacing: 6) {
            languageButton
            micButton
            modeButton
        }
        .padding(.horizontal, 5)
        .frame(height: 38)
    }

    /// Cycles ru → en → auto. Writes the same key the Recognition language
    /// dropdown in Settings uses, so the two always agree.
    private var languageButton: some View {
        Button {
            language = switch language {
            case "ru": "en"
            case "en": "auto"
            default: "ru"
            }
        } label: {
            Group {
                if language == "auto" {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .medium))
                } else {
                    Text(language.uppercased())
                        .font(Tokens.mono(10, weight: .medium))
                }
            }
            .foregroundStyle(Tokens.text2)
            .frame(width: 28, height: 28)
            .background(Tokens.surface2, in: Circle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(L("Язык распознавания"))
    }

    private var micButton: some View {
        Button {
            bar.setMenuOpen(false)
            coordinator.toggle()
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Tokens.textOnAccent)
                .frame(width: 36, height: 28)
                .background(selectedMode.tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(L("Начать запись"))
    }

    private var modeButton: some View {
        Button {
            bar.setMenuOpen(!bar.menuOpen)
        } label: {
            HStack(spacing: 5) {
                Text(L(selectedMode.label))
                    .font(Tokens.sans(11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(bar.menuOpen ? 180 : 0))
            }
            .foregroundStyle(bar.menuOpen ? Tokens.text : Tokens.textMeta)
            .padding(.leading, 9)
            .padding(.trailing, 7)
            .frame(height: 28)
            .background(bar.menuOpen ? Tokens.border : Tokens.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Mode list above the capsule. Unlike the mockup, the route caption and the
/// options live in one card split by a plain divider — two floating blocks read
/// as two separate popovers.
struct HUDModeMenu: View {
    let bar: HUDBarState

    @AppStorage(Prefs.Key.hudMode) private var mode: String = Prefs.HUDMode.dictation.rawValue
    @State private var hoveredMode: Prefs.HUDMode?

    private var selectedMode: Prefs.HUDMode {
        Prefs.HUDMode(rawValue: mode) ?? .dictation
    }

    /// The caption follows the cursor and falls back to the current choice.
    private var caption: String {
        L((hoveredMode ?? selectedMode).route)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(caption)
                .font(Tokens.sans(11.5))
                .foregroundStyle(Tokens.text3)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                // The caption is one or two lines depending on the mode; a fixed
                // height keeps the card from jumping as the cursor moves.
                .frame(height: 52, alignment: .center)

            Divider().overlay(Tokens.surface2)

            VStack(spacing: 0) {
                ForEach(Prefs.HUDMode.available, id: \.self) { item in
                    row(item)
                }
            }
            .padding(5)
        }
        .frame(width: 236)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Tokens.shadowHUD.opacity(0.14), radius: 16, y: 8)
    }

    private func row(_ item: Prefs.HUDMode) -> some View {
        let active = item == selectedMode
        let highlighted = item == hoveredMode
        let tint = item.tint
        return Button {
            mode = item.rawValue
            bar.setMenuOpen(false)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(active || highlighted ? tint : Tokens.text2)
                    .frame(width: 14)
                Text(L(item.label))
                    .font(Tokens.sans(11.5, weight: .medium))
                    .foregroundStyle(Tokens.text)
                Spacer(minLength: 8)
                Text(KeyboardShortcuts.Name.mode(item).shortcut?.description ?? "")
                    .font(Tokens.mono(11, weight: .medium))
                    .foregroundStyle(Tokens.text3)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(active ? 0.18 : (highlighted ? 0.10 : 0)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hoveredMode = $0 ? item : nil }
    }
}

extension Prefs.HUDMode {
    /// Each mode carries its own colour: red stays "on device", violet is a
    /// question over the API, blue is a screenshot over the API. The menu row
    /// picks it up on hover and when selected, so the choice reads before the click.
    var tint: Color {
        switch self {
        case .dictation: Tokens.accent
        case .ask: Tokens.remote
        case .screen: Tokens.capture
        // Calm on purpose: picking the mode only opens the panel, and the
        // accent has to stay the colour of "recording right now".
        case .meeting: Tokens.conversation
        }
    }
}
