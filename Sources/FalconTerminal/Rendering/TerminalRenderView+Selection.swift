import AppKit

/// Selection state + text extraction for the terminal surface.
extension TerminalRenderView {
    var maxColumns: Int { max(1, snapshot.columns) }
    var maxRows: Int { max(1, snapshot.rows) }

    func setSelectionAnchor(_ pos: GridPos) { selectionAnchor = pos }
    func setSelectionEnd(_ pos: GridPos) { selectionEnd = pos }

    func clearSelection() {
        selectionAnchor = nil
        selectionEnd = nil
        needsDisplay = true
    }

    var selectionIsEmpty: Bool {
        guard let a = selectionAnchor, let b = selectionEnd else { return true }
        return a == b
    }

    /// Selection normalized so `start` precedes `end` in reading order.
    func normalizedSelection() -> (start: GridPos, end: GridPos)? {
        guard let a = selectionAnchor, let b = selectionEnd else { return nil }
        if a.row < b.row || (a.row == b.row && a.col <= b.col) {
            return (a, b)
        }
        return (b, a)
    }

    func isSelected(row: Int, col: Int, selection: (start: GridPos, end: GridPos)?) -> Bool {
        guard let sel = selection else { return false }
        if row < sel.start.row || row > sel.end.row { return false }
        if sel.start.row == sel.end.row {
            return col >= sel.start.col && col <= sel.end.col
        }
        if row == sel.start.row { return col >= sel.start.col }
        if row == sel.end.row { return col <= sel.end.col }
        return true
    }

    /// The selected text, joining wrapped rows and trimming trailing blanks.
    func selectedText() -> String {
        guard let sel = normalizedSelection() else { return "" }
        var result = ""
        for row in sel.start.row...sel.end.row where row < snapshot.lines.count {
            let cells = snapshot.lines[row].cells
            let startCol = row == sel.start.row ? sel.start.col : 0
            let endCol = row == sel.end.row ? sel.end.col : cells.count - 1
            var lineStr = ""
            var c = max(0, startCol)
            while c <= min(endCol, cells.count - 1) {
                let cell = cells[c]
                if cell.attributes.contains(.wideTrailer) { c += 1; continue }
                lineStr += cell.string
                c += 1
            }
            while let last = lineStr.last, last == " " { lineStr.removeLast() }
            result += lineStr
            if row != sel.end.row { result += "\n" }
        }
        return result
    }
}
