import Foundation

/// Applies SGR (Select Graphic Rendition) parameter lists to a cursor's
/// graphic state. Handles the standard 16 colors, the 256-color (38/48;5)
/// and truecolor (38/48;2) forms, and the common attribute toggles.
enum SGR {
    static func apply(parameters rawParams: [Int?], to cursor: inout Cursor) {
        // A bare `CSI m` means reset.
        let params = rawParams.isEmpty ? [0] : rawParams.map { $0 ?? 0 }

        var i = 0
        while i < params.count {
            let code = params[i]
            switch code {
            case 0:
                cursor.resetGraphics()
            case 1:  cursor.attributes.insert(.bold)
            case 2:  cursor.attributes.insert(.faint)
            case 3:  cursor.attributes.insert(.italic)
            case 4:  cursor.attributes.insert(.underline)
            case 5, 6: cursor.attributes.insert(.blink)
            case 7:  cursor.attributes.insert(.inverse)
            case 8:  cursor.attributes.insert(.invisible)
            case 9:  cursor.attributes.insert(.strikethrough)
            case 21, 22: cursor.attributes.remove(.bold); cursor.attributes.remove(.faint)
            case 23: cursor.attributes.remove(.italic)
            case 24: cursor.attributes.remove(.underline)
            case 25: cursor.attributes.remove(.blink)
            case 27: cursor.attributes.remove(.inverse)
            case 28: cursor.attributes.remove(.invisible)
            case 29: cursor.attributes.remove(.strikethrough)
            case 30...37:
                cursor.foreground = .indexed(UInt8(code - 30))
            case 38:
                if let (color, consumed) = extendedColor(params, at: i) {
                    cursor.foreground = color; i += consumed; continue
                }
            case 39:
                cursor.foreground = .default
            case 40...47:
                cursor.background = .indexed(UInt8(code - 40))
            case 48:
                if let (color, consumed) = extendedColor(params, at: i) {
                    cursor.background = color; i += consumed; continue
                }
            case 49:
                cursor.background = .default
            case 90...97:
                cursor.foreground = .indexed(UInt8(code - 90 + 8))
            case 100...107:
                cursor.background = .indexed(UInt8(code - 100 + 8))
            default:
                break
            }
            i += 1
        }
    }

    /// Parses a `38`/`48` extended color spec starting at index `i`.
    /// Returns the color and the number of array elements consumed.
    private static func extendedColor(_ params: [Int], at i: Int) -> (TerminalColor, Int)? {
        guard i + 1 < params.count else { return nil }
        let mode = params[i + 1]
        switch mode {
        case 5: // 256-color: 38;5;n
            guard i + 2 < params.count else { return nil }
            let idx = params[i + 2]
            return (.indexed(UInt8(clamping: idx)), 3)
        case 2: // truecolor: 38;2;r;g;b
            guard i + 4 < params.count else { return nil }
            let r = UInt8(clamping: params[i + 2])
            let g = UInt8(clamping: params[i + 3])
            let b = UInt8(clamping: params[i + 4])
            return (.rgb(r: r, g: g, b: b), 5)
        default:
            return nil
        }
    }
}
