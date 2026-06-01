import Foundation

/// Column width of a Unicode scalar (a pragmatic `wcwidth`).
///
/// Returns 0 for combining marks / zero-width, 2 for the common wide
/// (East-Asian, emoji) ranges, and 1 otherwise. This is enough for correct
/// cursor advancement and CJK / emoji layout in the grid.
enum CharacterWidth {
    static func width(of scalar: Unicode.Scalar) -> Int {
        let v = scalar.value

        if v == 0 { return 0 }

        // Combining marks & zero-width.
        if isZeroWidth(v) { return 0 }

        if isWide(v) { return 2 }

        return 1
    }

    private static func isZeroWidth(_ v: UInt32) -> Bool {
        switch v {
        case 0x0300...0x036F,      // combining diacritical marks
             0x0483...0x0489,
             0x0591...0x05BD,
             0x0610...0x061A,
             0x064B...0x065F,      // Arabic combining marks
             0x0670,
             0x06D6...0x06DC,
             0x06DF...0x06E4,
             0x06E7...0x06E8,
             0x06EA...0x06ED,
             0x0E31, 0x0E34...0x0E3A,
             0x0E47...0x0E4E,
             0x200B...0x200F,      // zero-width space / marks / LRM-RLM
             0x202A...0x202E,      // bidi embedding controls
             0x2060...0x2064,
             0xFE00...0xFE0F,      // variation selectors
             0xFEFF:               // BOM / zero-width no-break
            return true
        default:
            return false
        }
    }

    private static func isWide(_ v: UInt32) -> Bool {
        switch v {
        case 0x1100...0x115F,      // Hangul Jamo
             0x2329...0x232A,
             0x2E80...0x303E,      // CJK radicals, Kangxi
             0x3041...0x33FF,      // Hiragana .. CJK symbols
             0x3400...0x4DBF,      // CJK Ext A
             0x4E00...0x9FFF,      // CJK Unified
             0xA000...0xA4CF,      // Yi
             0xAC00...0xD7A3,      // Hangul syllables
             0xF900...0xFAFF,      // CJK compatibility
             0xFE30...0xFE4F,      // CJK compatibility forms
             0xFF00...0xFF60,      // fullwidth forms
             0xFFE0...0xFFE6,
             0x1F300...0x1F6FF,    // emoji / pictographs / transport & map
             0x1F900...0x1F9FF,    // supplemental symbols & emoji
             0x1FA70...0x1FAFF,
             0x20000...0x3FFFD:    // CJK Ext B+
            return true
        default:
            return false
        }
    }
}
