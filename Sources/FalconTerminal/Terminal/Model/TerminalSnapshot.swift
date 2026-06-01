import Foundation

/// An immutable, `Sendable` view of the terminal grid for one frame. Produced
/// on the session's serial queue and handed to the renderer on the main
/// thread, so rendering never touches the live mutable buffer.
struct TerminalSnapshot: Sendable {
    var lines: [TerminalLine]
    var columns: Int
    var rows: Int

    var cursorRow: Int
    var cursorColumn: Int
    var cursorVisible: Bool
    var cursorStyle: CursorStyle

    var reverseVideo: Bool

    /// True when the viewport is pinned to the live bottom of the buffer.
    var atBottom: Bool

    /// True while the alternate screen is active (vim/htop/etc.), where inline
    /// suggestions must be suppressed.
    var altScreen: Bool

    static let empty = TerminalSnapshot(
        lines: [], columns: 0, rows: 0,
        cursorRow: 0, cursorColumn: 0, cursorVisible: false,
        cursorStyle: .block, reverseVideo: false, atBottom: true, altScreen: false
    )
}
