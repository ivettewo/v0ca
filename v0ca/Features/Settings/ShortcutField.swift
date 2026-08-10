import AppKit
import KeyboardShortcuts
import SwiftUI

/// Hotkey field per the "Screen · Settings" mockup, "SHORTCUTS" section:
/// the shortcut is shown as individual key caps (`<kbd>`: mono 12/500,
/// border with a thicker bottom edge, bg2 background); click enters recording
/// mode (pink dashed badge "Press a new shortcut…"), Esc cancels.
/// The stock `KeyboardShortcuts.Recorder` captures keys unreliably in a
/// menu-bar app, so we catch the event ourselves with a local monitor (like mind-wiki).
///
/// Lives in Features, not DesignSystem: it depends on KeyboardShortcuts and Prefs
/// (fn-hotkey logic) — we keep such dependencies out of the design system.
struct ShortcutField: View {
    let name: KeyboardShortcuts.Name
    /// UserDefaults key for "this shortcut is fn". When set, the field can capture fn.
    var fnPrefKey: String?
    /// Called after a new shortcut is assigned (including fn) — for external
    /// previews like the large keys in onboarding.
    var onChange: (() -> Void)?

    @State private var isRecording = false
    @State private var keys: [String] = []
    @State private var hovering = false
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?

    private var usesFn: Bool {
        guard let fnPrefKey else { return false }
        return UserDefaults.standard.bool(forKey: fnPrefKey)
    }

    /// 34px capsule — same field look in settings and onboarding
    /// ("Settings · New screens" mockup).
    private let height: CGFloat = 34
    private let radius: CGFloat = 17

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Group {
                if isRecording {
                    recordingLabel
                } else {
                    idleLabel
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: radius))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .onAppear(perform: refresh)
        .onDisappear(perform: stopRecording)
    }

    /// Idle: key caps, hover highlights the border and background.
    private var idleLabel: some View {
        HStack(spacing: 6) {
            if keys.isEmpty {
                Text("—")
                    .font(Tokens.mono(12, weight: .medium))
                    .foregroundStyle(Tokens.text3)
            } else {
                ForEach(keys, id: \.self) { keyCap($0) }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(
            hovering ? Tokens.background : Tokens.surface,
            in: RoundedRectangle(cornerRadius: radius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(hovering ? Tokens.text3 : Tokens.controlBorder, lineWidth: 1)
        )
    }

    /// Recording: pink badge, dashed 1.5px accent border (from the mockup).
    private var recordingLabel: some View {
        Text(L("Нажмите новую комбинацию…"))
            .font(Tokens.sans(12))
            .foregroundStyle(Tokens.accentHover)
            .frame(minWidth: 172)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(Tokens.accentSoft, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Tokens.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
    }

    /// A single key: `<kbd>` from the mockup — mono 12/500, border with a 2px
    /// bottom edge (an underlay border shifted down), radius 5, bg2 background.
    private func keyCap(_ symbol: String) -> some View {
        Text(symbol)
            .font(Tokens.mono(12, weight: .medium))
            .foregroundStyle(Tokens.text)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Tokens.background, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Tokens.border, lineWidth: 1))
            .background(RoundedRectangle(cornerRadius: 5).fill(Tokens.border).offset(y: 1))
    }

    /// Shortcut → individual keys in the canonical modifier order ⌃⌥⇧⌘.
    /// Static: onboarding uses it for the large key previews.
    static func keyParts(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
        var parts: [String] = []
        let modifiers = shortcut.modifiers
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if let key = shortcut.key {
            let label = KeyboardShortcuts.Shortcut(key, modifiers: []).description
            // Symbols that read worse than a label (the mockup uses "Esc", "Space").
            let pretty = ["⎋": "Esc", "␣": "Space", "⇥": "Tab"]
            parts.append(pretty[label] ?? label)
        }
        return parts
    }

    private func startRecording() {
        isRecording = true
        // While recording, mute all global hotkeys — otherwise the keypress
        // fires as an action (start recording) instead of being captured by the field.
        KeyboardShortcuts.isEnabled = false
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc — cancel recording
                stopRecording()
                return nil
            }
            if let shortcut = KeyboardShortcuts.Shortcut(event: event) {
                setFn(false)
                KeyboardShortcuts.setShortcut(shortcut, for: name)
                refresh()
                stopRecording()
                onChange?()
                return nil
            }
            return event
        }
        // fn doesn't produce keyDown — catch it with a separate flagsChanged monitor (keyCode 63).
        guard fnPrefKey != nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if event.keyCode == 63, event.modifierFlags.contains(.function) {
                setFn(true)
                KeyboardShortcuts.setShortcut(nil, for: name) // fn replaces the Carbon hotkey
                refresh()
                stopRecording()
                onChange?()
                return nil
            }
            return event
        }
    }

    private func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        keyMonitor = nil
        flagsMonitor = nil
        isRecording = false
        KeyboardShortcuts.isEnabled = true
    }

    private func setFn(_ on: Bool) {
        guard let fnPrefKey else { return }
        UserDefaults.standard.set(on, forKey: fnPrefKey)
    }

    private func refresh() {
        if usesFn {
            keys = ["fn"]
        } else if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            keys = Self.keyParts(shortcut)
        } else {
            keys = []
        }
    }
}
