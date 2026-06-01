import Foundation

/// Visual attributes attached to a single terminal cell, packed into a single
/// option set so the per-cell footprint stays small.
struct CellAttributes: OptionSet, Hashable, Sendable {
    let rawValue: UInt16

    init(rawValue: UInt16) { self.rawValue = rawValue }

    static let bold          = CellAttributes(rawValue: 1 << 0)
    static let faint         = CellAttributes(rawValue: 1 << 1)
    static let italic        = CellAttributes(rawValue: 1 << 2)
    static let underline     = CellAttributes(rawValue: 1 << 3)
    static let blink         = CellAttributes(rawValue: 1 << 4)
    static let inverse       = CellAttributes(rawValue: 1 << 5)
    static let invisible     = CellAttributes(rawValue: 1 << 6)
    static let strikethrough = CellAttributes(rawValue: 1 << 7)
    /// Second column of a wide (CJK / emoji) glyph; carries no character.
    static let wideTrailer    = CellAttributes(rawValue: 1 << 8)
    /// First column of a wide glyph; the character occupies two columns.
    static let wideLeader     = CellAttributes(rawValue: 1 << 9)
}
