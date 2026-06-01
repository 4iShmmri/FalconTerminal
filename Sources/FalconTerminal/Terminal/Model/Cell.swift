import Foundation

/// A single character cell in the terminal grid.
///
/// `scalars` holds the primary scalar plus any combining marks so that
/// graphemes such as accented or zero-width-joined sequences render intact.
struct Cell: Equatable, Sendable {
    var scalars: [Unicode.Scalar]
    var foreground: TerminalColor
    var background: TerminalColor
    var attributes: CellAttributes

    init(
        scalars: [Unicode.Scalar] = [" "],
        foreground: TerminalColor = .default,
        background: TerminalColor = .default,
        attributes: CellAttributes = []
    ) {
        self.scalars = scalars
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
    }

    /// A blank cell carrying the supplied colors/attributes (used when erasing
    /// so that background color fills correctly, matching xterm behaviour).
    static func blank(
        background: TerminalColor = .default,
        foreground: TerminalColor = .default
    ) -> Cell {
        Cell(scalars: [" "], foreground: foreground, background: background, attributes: [])
    }

    /// The rendered string for this cell.
    var string: String {
        var s = ""
        s.unicodeScalars.append(contentsOf: scalars)
        return s
    }

    var isBlank: Bool {
        scalars.count == 1 && scalars[0] == " " && background == .default && !attributes.contains(.inverse)
    }
}
