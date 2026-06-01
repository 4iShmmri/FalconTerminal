import Foundation

enum CursorStyle: Equatable, Sendable {
    case block
    case underline
    case bar
}

/// Cursor position and the pending-graphic state needed to faithfully emulate
/// the VT "wrap pending" behaviour (the cursor sits past the last column until
/// the next printable character forces the wrap).
struct Cursor: Equatable, Sendable {
    var row: Int = 0
    var column: Int = 0
    var visible: Bool = true
    var style: CursorStyle = .block

    /// Currently active graphic attributes applied to printed cells.
    var foreground: TerminalColor = .default
    var background: TerminalColor = .default
    var attributes: CellAttributes = []

    /// Set when the cursor has printed in the last column; the actual wrap is
    /// deferred until the next printable glyph (xterm "pending wrap" / VT100).
    var wrapPending: Bool = false

    mutating func resetGraphics() {
        foreground = .default
        background = .default
        attributes = []
    }
}
