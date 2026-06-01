import AppKit

/// Monospace font geometry used to lay cells out on a fixed grid.
struct FontMetrics {
    let font: NSFont
    let boldFont: NSFont
    let italicFont: NSFont
    let boldItalicFont: NSFont

    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let ascent: CGFloat
    let baselineOffset: CGFloat

    init(fontName: String, size: CGFloat) {
        let base = FontMetrics.makeFont(name: fontName, size: size)
        font = base
        boldFont = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        italicFont = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        boldItalicFont = NSFontManager.shared.convert(
            NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask),
            toHaveTrait: .italicFontMask
        )

        // Advance of a representative monospace glyph.
        let advance = base.advancement(forCGGlyph: base.glyph(for: "M") ?? 0).width
        cellWidth = (advance > 0 ? advance : size * 0.6).rounded(.up)

        let ascentValue = abs(base.ascender)
        let descentValue = abs(base.descender)
        let leading = base.leading
        cellHeight = (ascentValue + descentValue + leading).rounded(.up) + 1
        ascent = ascentValue
        baselineOffset = (cellHeight - (ascentValue + descentValue)) / 2
    }

    private static func makeFont(name: String, size: CGFloat) -> NSFont {
        if let f = NSFont(name: name, size: size) { return f }
        if let mono = NSFont(name: "SFMono-Regular", size: size) { return mono }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    func font(bold: Bool, italic: Bool) -> NSFont {
        switch (bold, italic) {
        case (true, true):  return boldItalicFont
        case (true, false): return boldFont
        case (false, true): return italicFont
        default:            return font
        }
    }
}

extension NSFont {
    fileprivate func glyph(for character: Character) -> CGGlyph? {
        let s = String(character)
        var chars = Array(s.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(self as CTFont, &chars, &glyphs, chars.count) else {
            return nil
        }
        return glyphs.first
    }
}
