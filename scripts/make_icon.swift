// App icon: "v0" on a white background — v in black, 0 in a contrasting orange.
// Font — Atkinson Hyperlegible Mono from the bundle (the logo font).
// Usage: swift scripts/make_icon.swift <output .iconset directory>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Register the logo font from the project resources
let fontURL = URL(fileURLWithPath: "v0ca/Resources/Fonts/AtkinsonHyperlegibleMono-SemiBold.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func logoFont(size: CGFloat) -> NSFont {
    NSFont(name: "AtkinsonHyperlegibleMono-SemiBold", size: size)
        ?? NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
}

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / 1024.0

    // White rounded square
    let inset = 100.0 * s
    let bgRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: 185 * s, yRadius: 185 * s)
    NSColor.white.setFill()
    bg.fill()

    // Subtle gray border so the icon doesn't blend into light backgrounds
    let borderInset = inset + 3 * s
    let borderRect = NSRect(x: borderInset, y: borderInset, width: size - borderInset * 2, height: size - borderInset * 2)
    let border = NSBezierPath(roundedRect: borderRect, xRadius: 182 * s, yRadius: 182 * s)
    border.lineWidth = 6 * s
    NSColor(srgbRed: 0xD9 / 255.0, green: 0xD9 / 255.0, blue: 0xDE / 255.0, alpha: 1).setStroke()
    border.stroke()

    // "v0": v — black #1B1B1F, 0 — contrasting orange
    let black = NSColor(srgbRed: 0x1B / 255.0, green: 0x1B / 255.0, blue: 0x1F / 255.0, alpha: 1)
    let orange = NSColor(srgbRed: 0xFF / 255.0, green: 0x6B / 255.0, blue: 0x00 / 255.0, alpha: 1)
    let font = logoFont(size: 540 * s)

    let text = NSMutableAttributedString()
    text.append(NSAttributedString(string: "v", attributes: [.font: font, .foregroundColor: black, .kern: -14 * s]))
    text.append(NSAttributedString(string: "0", attributes: [.font: font, .foregroundColor: orange]))

    let bounds = text.boundingRect(with: NSSize(width: size, height: size), options: [.usesLineFragmentOrigin])
    let point = NSPoint(
        x: (size - bounds.width) / 2 - bounds.minX,
        y: (size - bounds.height) / 2 - bounds.minY
    )
    text.draw(at: point)

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixels: Int, name: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

let master = draw(size: 1024)
for (points, scales) in [16: [1, 2], 32: [1, 2], 128: [1, 2], 256: [1, 2], 512: [1, 2]] {
    for scale in scales {
        let name = scale == 1 ? "icon_\(points)x\(points)" : "icon_\(points)x\(points)@\(scale)x"
        writePNG(master, pixels: points * scale, name: name)
    }
}
print("OK: \(outDir)")
