import AppKit
import ApplicationServices
import OSLog

/// Глобальный монитор клавиши fn (🌐 Globe).
///
/// Carbon `RegisterEventHotKey` (и библиотека KeyboardShortcuts) не умеют fn:
/// эта клавиша не даёт keycode, а лишь выставляет флаг `maskSecondaryFn`.
/// Поэтому, как в приложении handy (крейт `handy-keys`), ловим её низкоуровневым
/// `CGEventTap` по событиям `.flagsChanged`. Требуется разрешение Accessibility —
/// то же, что уже нужно v0ca для вставки текста (CGEvent).
@MainActor
final class FnHotkeyMonitor {
    /// fn нажата (флаг появился) и отпущена (флаг пропал).
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false
    private let log = Logger(subsystem: "com.v0ca.app", category: "FnHotkeyMonitor")

    /// Ставит event tap. Идемпотентно; без Accessibility молча ничего не делает.
    func start() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else {
            log.info("fn-монитор не запущен: нет разрешения Accessibility")
            return
        }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

                // Систему может отключить tap при перегрузке — включаем обратно.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    MainActor.assumeIsolated { monitor.reenable() }
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
