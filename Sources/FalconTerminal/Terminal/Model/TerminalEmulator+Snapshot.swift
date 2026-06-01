import Foundation

/// Read-only accessors and snapshot generation used by the session layer.
extension TerminalEmulator {
    var bracketedPasteEnabled: Bool { modes.bracketedPaste }
    var applicationCursorKeysEnabled: Bool { modes.applicationCursorKeys }

    /// Number of history lines available above the visible screen. The alt
    /// screen has no scrollback.
    var scrollbackCount: Int { modes.altScreen ? 0 : main.scrollback.count }

    /// Build an immutable viewport snapshot. `viewportOffset` is the number of
    /// lines scrolled up from the live bottom (0 = pinned to bottom).
    func makeSnapshot(viewportOffset: Int) -> TerminalSnapshot {
        let total = buffer.totalRows
        let visibleRows = rows
        let bottomStart = total - visibleRows
        let clampedOffset = max(0, min(viewportOffset, buffer.scrollback.count))
        let start = max(0, bottomStart - clampedOffset)

        var lines: [TerminalLine] = []
        lines.reserveCapacity(visibleRows)
        for i in 0..<visibleRows {
            lines.append(buffer.combinedLine(at: start + i))
        }

        let atBottom = clampedOffset == 0
        return TerminalSnapshot(
            lines: lines,
            columns: columns,
            rows: visibleRows,
            cursorRow: cursor.row,
            cursorColumn: cursor.column,
            cursorVisible: atBottom && cursor.visible && modes.cursorVisible,
            cursorStyle: cursor.style,
            reverseVideo: modes.reverseVideo,
            atBottom: atBottom,
            altScreen: modes.altScreen
        )
    }

    /// Whole-buffer plain text (scrollback + screen) for select-all / export.
    func allText() -> String {
        var out: [String] = []
        out.reserveCapacity(buffer.totalRows)
        for i in 0..<buffer.totalRows {
            out.append(buffer.combinedLine(at: i).plainText)
        }
        // Drop trailing empty lines.
        while let last = out.last, last.isEmpty { out.removeLast() }
        return out.joined(separator: "\n")
    }
}
