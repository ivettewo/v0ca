import AppKit
import ApplicationServices
import OSLog

/// Global monitor for the fn key (🌐 Globe) and Esc cancellation.
///
/// Carbon `RegisterEventHotKey` (and the KeyboardShortcuts library) can't handle fn:
/// the key produces no keycode, it only sets the `maskSecondaryFn` flag.
/// So, like the handy app (the `handy-keys` crate), we catch it with a low-level
/// `CGEventTap` on `.flagsChanged` events. Requires the Accessibility permission —
/// the same one v0ca already needs for text insertion (CGEvent).
///
/// The same tap also catches Esc `keyDown`: the Carbon cancel hotkey is registered as
/// "Esc with no modifiers" and doesn't fire while fn/⌥ is held in push-to-talk —
/// the event arrives as "fn+Esc" and doesn't match. The tap only looks at the keycode.
@MainActor
final class FnHotkeyMonitor {
    /// fn pressed (flag appeared) and released (flag disappeared).
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?
    /// Esc pressed (with any modifiers). Return `true` to mark the event handled
    /// and swallow it (it won't reach the active app), like a Carbon hotkey.
    var onEscape: (() -> Bool)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false
    private let log = Logger(category: "FnHotkeyMonitor")

    /// Installs the event tap. Idempotent; silently does nothing without Accessibility.
    func start() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else {
            log.info("fn-монитор не запущен: нет разрешения Accessibility")
            return
        }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        // .defaultTap (not .listenOnly): the Esc cancellation must be swallowed
        // by returning nil — otherwise Esc would reach the active app.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // The system may disable the tap under load — re-enable it.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    MainActor.assumeIsolated { monitor.reenable() }
                    return Unmanaged.passUnretained(event)
                }

                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == 53 { // Esc
                        let handled = MainActor.assumeIsolated { monitor.onEscape?() ?? false }
                        if handled { return nil }
                    }
                    return Unmanaged.passUnretained(event)
                }

                let hasFn = event.flags.contains(.maskSecondaryFn)
                MainActor.assumeIsolated { monitor.handle(fnDown: hasFn) }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            log.error("Не удалось создать CGEventTap для fn")
            return
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        log.info("fn-монитор запущен")
    }

    private func handle(fnDown: Bool) {
        guard fnDown != fnIsDown else { return }
        fnIsDown = fnDown
        (fnDown ? onFnDown : onFnUp)?()
    }

    private func reenable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}
