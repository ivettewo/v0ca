import AppKit
import Carbon.HIToolbox

/// Вставка транскрипта в активное приложение: буфер обмена + синтетический ⌘V.
/// Требует разрешения Accessibility (запрашивается при первой вставке).
enum TextInserter {
    @MainActor
    static func insert(_ text: String) {
        // «Печатать без буфера»: текст вводится синтетическими нажатиями,
        // буфер обмена вообще не участвует.
        if Prefs.insertMethod == .type {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            guard AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) else { return }
            typeUnicode(text)
            if Prefs.autoSend == .enter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    postKeystroke(CGKeyCode(kVK_Return), flags: [])
                }
            }
            return
        }

        let pasteboard = NSPasteboard.general

        // «Не изменять» (по умолчанию): снимаем полную копию содержимого буфера
        // (любые типы: текст, картинки, файлы) и вернём её после вставки. Пустой буфер
        // тоже валидное состояние: тогда после вставки просто очистим.
        let savedItems: [NSPasteboardItem]? = Prefs.clipboardHandling == .unchanged
            ? (pasteboard.pasteboardItems ?? []).map { item in
                let copy = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        copy.setData(data, forType: type)
                    }
                }
                return copy
            }
            : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard Prefs.insertMethod == .paste else { return } // «Только буфер обмена»

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        guard AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) else {
            // Разрешения нет — текст остаётся в буфере, пользователь вставит сам.
            return
        }

        postKeystroke(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        if Prefs.autoSend == .enter {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                postKeystroke(CGKeyCode(kVK_Return), flags: [])
            }
        }

        if let savedItems {
            // Вернуть прежний буфер после того, как ⌘V успел отработать.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                if !savedItems.isEmpty {
                    pasteboard.writeObjects(savedItems)
                }
            }
        }
    }

    /// Синтетический ввод текста порциями по 20 UTF-16 единиц
    /// (надёжный максимум для CGEventKeyboardSetUnicodeString).
    private static func typeUnicode(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        var index = 0
        while index < units.count {
            let chunk = Array(units[index..<min(index + 20, units.count)])
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown)
                event?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event?.post(tap: .cghidEventTap)
            }
            index += 20
        }
    }

    private static func postKeystroke(_ key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
