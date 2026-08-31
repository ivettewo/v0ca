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

    /// How hard we squeeze the picture before sending.
    ///
    /// Baseline: fit the long side and encode once. Providers bill by pixels and
    /// cap the image size, so a 5K screenshot is both rejected and expensive.
    ///
    /// The "Screenshot optimization" module tightens this into a byte budget: a
    /// smaller frame and a quality ladder walked down until the image fits. The
    /// floor is deliberate — compress past it and the model can no longer read
    /// the text on screen, which is the entire point of the mode.
    private struct Squeeze {
        let maxSide: CGFloat
        /// Tried in order, best first.
        let quality: [CGFloat]
        /// Stop as soon as the encoded size is under this. Nil — take the first.
        let maxBytes: Int?
        /// Last resort when even the lowest quality misses the budget.
        let fallbackSide: CGFloat?

        static let baseline = Squeeze(
            maxSide: 1536, quality: [0.8], maxBytes: nil, fallbackSide: nil
        )
        static let optimized = Squeeze(
            maxSide: 1280,
            quality: [0.8, 0.7, 0.6, 0.5, 0.45],
            maxBytes: 300_000,
            fallbackSide: 1024
        )

        /// Both have to agree: the module puts the switch on the Providers tab,
        /// the switch says whether to squeeze. Without the module there is no
        /// switch to consult, and the baseline applies.
        static var current: Squeeze {
            guard ModuleCatalog.isEnabled("screenshot") else { return .baseline }
            let on = UserDefaults.standard.object(
                forKey: Prefs.Key.optimizeScreenshots
            ) as? Bool ?? true
            return on ? .optimized : .baseline
        }
    }

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
    /// `optimized` says whether the module's squeeze was the one that ran — the
    /// caller uses it for the achievement, and only truth earns that.
    static func captureDisplayUnderCursor() async throws
        -> (jpeg: Data, preview: NSImage, optimized: Bool) {
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
        return (encoded.jpeg, encoded.preview, Squeeze.current.maxBytes != nil)
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

    /// Fit the frame and encode as JPEG — good enough for reading a screen, and a
    /// fraction of the bytes of a PNG.
    private static func downscaledJPEG(_ image: CGImage) -> (jpeg: Data, preview: NSImage)? {
        let squeeze = Squeeze.current
        guard var best = encode(image, side: squeeze.maxSide, quality: squeeze.quality) else {
            return nil
        }

        // Still over budget at the lowest quality: give up pixels rather than
        // legibility of what is left.
        if let budget = squeeze.maxBytes, best.jpeg.count > budget,
           let side = squeeze.fallbackSide,
           let smaller = encode(image, side: side, quality: squeeze.quality) {
            best = smaller
        }

        let originalPixels = image.width * image.height
        log.info("""
        Снимок: \(originalPixels / 1000, privacy: .public)K пикселей → \
        \(Int(best.preview.size.width), privacy: .public)×\
        \(Int(best.preview.size.height), privacy: .public), \
        \(best.jpeg.count / 1024, privacy: .public) КБ
        """)
        return (best.jpeg, best.preview)
    }

    /// Renders once at `side` and walks the quality ladder until the result fits
    /// the budget. Re-encoding is cheap; re-rendering is not, so the bitmap is
    /// reused across attempts.
    private static func encode(
        _ image: CGImage,
        side: CGFloat,
        quality: [CGFloat]
    ) -> (jpeg: Data, preview: NSImage)? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(1, side / max(width, height))
        let target = NSSize(width: (width * scale).rounded(), height: (height * scale).rounded())

        let source = NSImage(cgImage: image, size: NSSize(width: width, height: height))
        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: target))
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        let budget = Squeeze.current.maxBytes
        var last: Data?
        for factor in quality {
            guard let data = rep.representation(
                using: .jpeg, properties: [.compressionFactor: factor]
            ) else {
                continue
            }
            last = data
            if let budget, data.count > budget { continue }
            return (data, resized)
        }
        return last.map { ($0, resized) }
    }
}
