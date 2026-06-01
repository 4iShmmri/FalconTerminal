import AppKit

/// A plain RGB color, `Codable` for persistence and convertible to `NSColor`.
struct RGBColor: Codable, Hashable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r; self.g = g; self.b = b
    }

    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        r = UInt8((value >> 16) & 0xFF)
        g = UInt8((value >> 8) & 0xFF)
        b = UInt8(value & 0xFF)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

/// A complete terminal color scheme: UI colors plus the 16 base ANSI colors.
struct Theme: Codable, Hashable, Sendable, Identifiable {
    var id: String { name }
    var name: String
    var isDark: Bool

    var background: RGBColor
    var foreground: RGBColor
    var cursor: RGBColor
    var cursorText: RGBColor
    var selection: RGBColor

    /// ANSI 0..15 (normal 0..7, bright 8..15).
    var palette: [RGBColor]

    /// Resolve a `TerminalColor` to an RGB color, applying bold→bright when
    /// requested (xterm convention) and falling back to defaults.
    func resolve(_ color: TerminalColor, isForeground: Bool, bold: Bool = false) -> RGBColor {
        switch color {
        case .default:
            return isForeground ? foreground : background
        case .rgb(let r, let g, let b):
            return RGBColor(r, g, b)
        case .indexed(let index):
            var idx = Int(index)
            if bold && idx < 8 { idx += 8 }
            return resolveIndexed(idx)
        }
    }

    /// Map a 256-color index to RGB: 0..15 from the palette, 16..231 from the
    /// 6×6×6 cube, 232..255 from the grayscale ramp.
    func resolveIndexed(_ index: Int) -> RGBColor {
        if index < 16 { return palette[min(index, palette.count - 1)] }
        if index >= 16 && index <= 231 {
            let i = index - 16
            let r = i / 36
            let g = (i / 6) % 6
            let b = i % 6
            func level(_ v: Int) -> UInt8 { v == 0 ? 0 : UInt8(55 + v * 40) }
            return RGBColor(level(r), level(g), level(b))
        }
        let gray = UInt8(8 + (index - 232) * 10)
        return RGBColor(gray, gray, gray)
    }
}
