import AppKit
import KeyboardShortcuts
import SwiftUI

/// Поле хоткея — по макету «Экран · Настройки», секция «КОМБИНАЦИИ»:
/// комбинация показана отдельными клавишами-капами (`<kbd>`: mono 12/500,
/// рамка с утолщённой нижней кромкой, фон bg2); клик — режим записи
/// (розовая плашка с пунктиром «Нажмите новую комбинацию…»), Esc — отмена.
/// Штатный `KeyboardShortcuts.Recorder` в menu-bar-приложении ненадёжно захватывает
/// клавиши, поэтому ловим событие сами локальным монитором (как в mind-wiki).
///
/// Живёт в Features, а не в DesignSystem: завязан на KeyboardShortcuts и Prefs
/// (логика fn-хоткея) — дизайн-систему такими зависимостями не нагружаем.
struct ShortcutField: View {
    let name: KeyboardShortcuts.Name
    /// Ключ UserDefaults «эта комбинация — fn». Если задан, поле умеет ловить fn.
    var fnPrefKey: String?

    @State private var isRecording = false
    @State private var keys: [String] = []
    @State private var hovering = false
    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?

    private var usesFn: Bool {
        guard let fnPrefKey else { return false }
        return UserDefaults.standard.bool(forKey: fnPrefKey)
    }

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
            .contentShape(RoundedRectangle(cornerRadius: Tokens.radiusControl))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { hovering = $0 }
        .onAppear(perform: refresh)
        .onDisappear(perform: stopRecording)
    }

    /// Покой: капы клавиш, hover подсвечивает рамку и фон.
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
        .frame(height: 32)
        .background(
            hovering ? Tokens.background : Tokens.surface,
            in: RoundedRectangle(cornerRadius: Tokens.radiusControl)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.radiusControl)
                .strokeBorder(hovering ? Tokens.text3 : Tokens.border, lineWidth: 1)
        )
    }

    /// Запись: розовая плашка, пунктирная акцентная рамка 1.5px (из макета).
    private var recordingLabel: some View {
        Text(L("Нажмите новую комбинацию…"))
            .font(Tokens.sans(12))
            .foregroundStyle(Tokens.accentHover)
            .frame(minWidth: 172)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Tokens.accentSoft, in: RoundedRectangle(cornerRadius: Tokens.radiusControl))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.radiusControl)
                    .strokeBorder(Tokens.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
    }

    /// Одна клавиша: `<kbd>` из макета — mono 12/500, рамка border с нижней
    /// кромкой 2px (рамка-подложка со сдвигом вниз), радиус 5, фон bg2.
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

    /// Комбинация → отдельные клавиши в каноничном порядке модификаторов ⌃⌥⇧⌘.
    private func keyParts(_ shortcut: KeyboardShortcuts.Shortcut) -> [String] {
        var parts: [String] = []
        let modifiers = shortcut.modifiers
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        if let key = shortcut.key {
            let label = KeyboardShortcuts.Shortcut(key, modifiers: []).description
            // Символы, которые читаются хуже подписи (в макете — «Esc», «Space»).
            let pretty = ["⎋": "Esc", "␣": "Space", "⇥": "Tab"]
            parts.append(pretty[label] ?? label)
        }
        return parts
    }

    private func startRecording() {
        isRecording = true
        // Пока записываем — глушим все глобальные хоткеи, иначе нажатие
        // сработает как действие (старт записи), а не запишется в поле.
        KeyboardShortcuts.isEnabled = false
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc — отмена записи
                stopRecording()
                return nil
            }
            if let shortcut = KeyboardShortcuts.Shortcut(event: event) {
                setFn(false)
                KeyboardShortcuts.setShortcut(shortcut, for: name)
                refresh()
                stopRecording()
                return nil
            }
            return event
        }
        // fn не даёт keyDown — ловим отдельным монитором flagsChanged (keyCode 63).
        guard fnPrefKey != nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            if event.keyCode == 63, event.modifierFlags.contains(.function) {
                setFn(true)
                KeyboardShortcuts.setShortcut(nil, for: name) // fn заменяет Carbon-хоткей
                refresh()
                stopRecording()
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
            keys = keyParts(shortcut)
        } else {
            keys = []
        }
    }
}
