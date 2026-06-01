import AppKit

// Renders the Falcon Terminal app icon: a sharp-edged (non-rounded) black
// square with a white prompt chevron and an accent cursor block.
// Usage: swift IconGenerator.swift <output-iconset-dir>

let accent = NSColor(srgbRed: 0x4C / 255, green: 0x8D / 255, blue: 1.0, alpha: 1)
let promptColor = NSColor(srgbRed: 0xEA / 255, green: 0xEA / 255, blue: 0xEA / 255, alpha: 1)

func draw(size s: CGFloat) {
    // Background: pure black, full square — deliberately sharp corners.
    NSColor.black.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: s, height: s)).fill()

    // Subtle full-height sheen for depth without softening the edges.
    let sheen = NSGradient(colors: [
        NSColor(white: 0.09, alpha: 1),
        NSColor(white: 0.0, alpha: 1)
    ])
    sheen?.draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: s, height: s)), angle: 90)

    // Thin hard frame just inside the edge to emphasise the square.
    let frame = NSBezierPath(rect: NSRect(x: s * 0.045, y: s * 0.045, width: s * 0.91, height: s * 0.91))
    frame.lineWidth = max(1, s * 0.012)
    NSColor(white: 0.18, alpha: 1).setStroke()
    frame.stroke()

    // Prompt chevron "❯" — sharp caps and miter joins.
    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: s * 0.27, y: s * 0.66))
    chevron.line(to: NSPoint(x: s * 0.43, y: s * 0.50))
    chevron.line(to: NSPoint(x: s * 0.27, y: s * 0.34))
    chevron.lineWidth = s * 0.075
    chevron.lineCapStyle = .butt
    chevron.lineJoinStyle = .miter
    promptColor.setStroke()
    chevron.stroke()

    // Cursor block.
    accent.setFill()
    NSBezierPath(rect: NSRect(x: s * 0.52, y: s * 0.435, width: s * 0.21, height: s * 0.13)).fill()
}

func pngData(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(size: CGFloat(size))
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (filename, pixel size) pairs required for a macOS iconset.
let variants: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for (name, size) in variants {
    let data = pngData(size: size)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Wrote \(variants.count) icon variants to \(outDir)")
