import AppKit
import SwiftUI

/// Отладочный рендер скриншотов онбординга: запуск приложения с переменной
/// окружения `V0CA_ONBOARDING_SHOTS=<папка>` рендерит все экраны в PNG
/// (английский, светлая тема, фирменный красный акцент) и завершает приложение.
/// Пользовательские настройки языка/акцента восстанавливаются.
/// Часы анимаций онбординга: в скриншотном режиме время заморожено на
/// репрезентативной секунде (все элементы видимы), иначе — реальное.
enum OnboardingClock {
    static let frozen = ProcessInfo.processInfo.environment["V0CA_ONBOARDING_SHOTS"] != nil

    static func elapsed(_ date: Date, since start: Date) -> TimeInterval {
        frozen ? 1.0 : date.timeIntervalSince(start)
    }
}

@MainActor
enum OnboardingScreenshots {
    static func runIfRequested(models: ModelManager) -> Bool {
        guard let path = ProcessInfo.processInfo.environment["V0CA_ONBOARDING_SHOTS"] else {
            return false
        }
        render(models: models, to: URL(fileURLWithPath: path))
        NSApp.terminate(nil)
        return true
    }

    private static func render(models: ModelManager, to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let savedLanguage = AppLanguage.shared.code
        let savedAccent = AccentStore.shared.hex
        AppLanguage.shared.code = .en
        AccentStore.shared.hex = "E03E3E"
        defer {
            AppLanguage.shared.code = savedLanguage
            AccentStore.shared.hex = savedAccent
        }

        let names: [OnboardingView.Step: String] = [
            .intro: "01-intro",
            .powerFree: "02-power-free",
            .permissions: "03-permissions",
            .modelIntro: "04-model-intro",
            .models: "05-models",
            .shortcutIntro: "06-shortcut-intro",
            .shortcuts: "07-shortcuts",
            .done: "08-final",
        ]

        // Окно не показываем (без orderFront), оно нужно только ради
        // retina-масштаба бэкинга при cacheDisplay.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)

        for step in OnboardingView.Step.allCases {
            let host = NSHostingView(
                rootView: OnboardingView(models: models, step: step, close: {})
            )
            host.frame = NSRect(x: 0, y: 0, width: 720, height: 600)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            // Даём ранлупу обработать onAppear-стейт (клавиши превью и т.п.).
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            let name = names[step] ?? "step-\(step.rawValue)"
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}
