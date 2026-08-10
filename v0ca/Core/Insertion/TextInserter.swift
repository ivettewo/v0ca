import AppKit
import Carbon.HIToolbox

/// Inserts the transcript into the active app: clipboard + synthetic ⌘V.
/// Requires the Accessibility permission (prompted on first insertion).
enum TextInserter {
    @MainActor
    static func insert(_ text: String) {
        // "Type without clipboard": the text is entered with synthetic keystrokes,
        // the clipboard is not involved at all.
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

        // "Keep unchanged" (default): take a full copy of the clipboard contents
        // (any types: text, images, files) and restore it after pasting. An empty
        // clipboard is also a valid state: then we just clear it after pasting.
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

        guard Prefs.insertMethod == .paste else { return } // "Clipboard only"

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        guard AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) else {
            // No permission — the text stays in the clipboard, the user pastes it manually.
            return
        }

        postKeystroke(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

        if Prefs.autoSend == .enter {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                postKeystroke(CGKeyCode(kVK_Return), flags: [])
            }
        }

        if let savedItems {
            // Restore the previous clipboard once ⌘V has had time to complete.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                if !savedItems.isEmpty {
                    pasteboard.writeObjects(savedItems)
                }
            }
        }
    }

    /// Synthetic text input in chunks of 20 UTF-16 units
    /// (the reliable maximum for CGEventKeyboardSetUnicodeString).
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
