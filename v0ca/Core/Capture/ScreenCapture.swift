import AppKit
import CoreGraphics
import OSLog
import ScreenCaptureKit

/// Takes the screenshot for the "Screen" mode. The image never touches the disk:
/// it is handed straight to the caller, sent, and dropped. A folder of full-screen
/// captures would be the most sensitive thing this app ever produced.
enum ScreenCapture {
    enum Failure: Error {
        case noPermission
        case noDisplay
        case failed
    }

    private static let log = Logger(category: "ScreenCapture")

    /// The long side we downscale to before sending. Providers bill by pixels and
    /// cap the image size; a 5K screenshot is both rejected and expensive.
    private static let maxSide: CGFloat = 1536

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Shows the system prompt the first time; afterwards macOS only lets the user
    /// change it in System Settings.
    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// The whole display the cursor is on, without our own HUD in it.
    static func captureDisplayUnderCursor() async throws -> (jpeg: Data, preview: NSImage) {
        guard hasPermission else { throw Failure.noPermission }
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        guard let display = displayUnderCursor(content.displays) else { throw Failure.noDisplay }

        // Our panel floats above everything, so without this the bar — and on a
        // re-shot the bubble itself — would end up inside the picture.
        let ourApp = content.applications.first {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: [ourApp].compactMap { $0 },
            exceptingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.captureResolution = .best
        configuration.showsCursor = false

        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: configuration
            )
        } catch {
            log.error("Снимок экрана не сделан: \(error)")
            throw Failure.failed
        }
        guard let encoded = downscaledJPEG(image) else { throw Failure.failed }
        return encoded
    }

    /// Which display holds the mouse. `NSEvent.mouseLocation` is in Cocoa
    /// coordinates, so the y axis has to be flipped to match CoreGraphics.
    private static func displayUnderCursor(_ displays: [SCDisplay]) -> SCDisplay? {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let number = screen?.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? CGDirectDisplayID else {
            return displays.first
        }
        return displays.first { $0.displayID == number } ?? displays.first
    }

    /// Fit into `maxSide` and encode as JPEG — good enough for reading a screen,
    /// and a fraction of the bytes of a PNG.
    private static func downscaledJPEG(_ image: CGImage) -> (jpeg: Data, preview: NSImage)? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(1, maxSide / max(width, height))
        let target = NSSize(width: (width * scale).rounded(), height: (height * scale).rounded())

        let source = NSImage(cgImage: image, size: NSSize(width: width, height: height))
        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: target))
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
            return nil
        }
        return (jpeg, resized)
    }
}
