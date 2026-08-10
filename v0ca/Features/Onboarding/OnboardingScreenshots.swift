import AppKit
import SwiftUI

/// Debug rendering of onboarding screenshots: launching the app with the
/// `V0CA_ONBOARDING_SHOTS=<folder>` environment variable renders all screens to PNG
/// (English, light theme, brand red accent) and quits the app.
/// The user's language/accent settings are restored.
/// Onboarding animation clock: in screenshot mode time is frozen at a
/// representative second (all elements visible), otherwise it's real time.
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

        // The window is never shown (no orderFront); it exists only for the
        // retina backing scale during cacheDisplay.
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
            // Let the run loop process onAppear state (preview keys, etc.).
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
