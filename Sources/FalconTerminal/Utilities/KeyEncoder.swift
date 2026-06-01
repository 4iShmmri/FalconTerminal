import AppKit

/// Translates AppKit key events into the byte sequences a terminal expects,
/// honoring application-cursor-key mode and the usual Ctrl/Alt conventions.
enum KeyEncoder {
    /// Returns the bytes to send for a key event, or nil if it should be
    /// handled elsewhere (e.g. a menu shortcut).
    static func encode(event: NSEvent, applicationCursorKeys: Bool) -> String? {
        let flags = event.modifierFlags
        let hasControl = flags.contains(.control)
        let hasOption = flags.contains(.option)
        let hasCommand = flags.contains(.command)

        // Command shortcuts are reserved for the app (tabs, copy, etc.).
        if hasCommand { return nil }

        let key = Int(event.keyCode)

        // Special keys by keyCode.
        if let special = specialKey(keyCode: key, applicationCursorKeys: applicationCursorKeys, flags: flags) {
            return special
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return nil
        }

        // Control combinations.
        if hasControl, let scalar = characters.unicodeScalars.first {
            if let ctrl = controlByte(for: scalar) {
                if hasOption { return "\u{1b}" + ctrl }
                return ctrl
            }
        }

        // Option as ESC-prefix (Meta) — common terminal convention.
        let text = event.characters ?? characters
        if hasOption {
            return "\u{1b}" + text
        }

        return text
    }

    private static func specialKey(
        keyCode: Int,
        applicationCursorKeys: Bool,
        flags: NSEvent.ModifierFlags
    ) -> String? {
        let ss3OrCsi = applicationCursorKeys ? "O" : "["
        switch keyCode {
        case 126: return "\u{1b}\(ss3OrCsi)A" // Up
        case 125: return "\u{1b}\(ss3OrCsi)B" // Down
        case 124: return "\u{1b}\(ss3OrCsi)C" // Right
        case 123: return "\u{1b}\(ss3OrCsi)D" // Left
        case 115: return "\u{1b}[H"            // Home
        case 119: return "\u{1b}[F"            // End
        case 116: return "\u{1b}[5~"           // Page Up
        case 121: return "\u{1b}[6~"           // Page Down
        case 117: return "\u{1b}[3~"           // Forward Delete
        case 51:  return "\u{7f}"              // Backspace -> DEL
        case 36:  return "\r"                  // Return
        case 76:  return "\r"                  // Keypad Enter
        case 48:                               // Tab
            return flags.contains(.shift) ? "\u{1b}[Z" : "\t"
        case 53:  return "\u{1b}"              // Escape
        case 122: return "\u{1b}OP"            // F1
        case 120: return "\u{1b}OQ"            // F2
        case 99:  return "\u{1b}OR"            // F3
        case 118: return "\u{1b}OS"            // F4
        case 96:  return "\u{1b}[15~"          // F5
        case 97:  return "\u{1b}[17~"          // F6
        case 98:  return "\u{1b}[18~"          // F7
        case 100: return "\u{1b}[19~"          // F8
        case 101: return "\u{1b}[20~"          // F9
        case 109: return "\u{1b}[21~"          // F10
        case 103: return "\u{1b}[23~"          // F11
        case 111: return "\u{1b}[24~"          // F12
        default:  return nil
        }
    }

    /// Maps a character to its Ctrl- control byte (Ctrl-A = 0x01, etc.).
    private static func controlByte(for scalar: Unicode.Scalar) -> String? {
        let v = scalar.value
        switch v {
        case 0x40...0x5F: // @ A..Z [ \ ] ^ _
            return String(Unicode.Scalar(v - 0x40)!)
        case 0x61...0x7A: // a..z
            return String(Unicode.Scalar(v - 0x60)!)
        case 0x20: return "\u{00}"       // Ctrl-Space -> NUL
        case 0x2F: return "\u{1f}"       // Ctrl-/ -> US
        default: return nil
        }
    }
}
