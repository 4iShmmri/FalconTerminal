import Foundation

/// One row of cells plus a flag recording whether the line wrapped (so that
/// reflow and copy/paste can rejoin soft-wrapped lines).
struct TerminalLine: Sendable {
    var cells: [Cell]
    var wrapped: Bool = false

    init(width: Int, blank: Cell = Cell()) {
        cells = Array(repeating: blank, count: max(width, 1))
    }

    mutating func resize(to width: Int, blank: Cell) {
        if width > cells.count {
            cells.append(contentsOf: Array(repeating: blank, count: width - cells.count))
        } else if width < cells.count {
            cells.removeLast(cells.count - width)
        }
    }

    var plainText: String {
        var s = ""
        for c in cells { s += c.string }
        // Trim trailing blanks for readable copy output.
        while let last = s.last, last == " " { s.removeLast() }
        return s
    }
}

/// The screen grid plus scrollback. All editing primitives the VT emulator
/// needs live here; the emulator translates parsed sequences into these calls.
///
/// Coordinates are 0-based with row 0 at the top of the *visible* screen.
final class TerminalBuffer {
    private(set) var rows: Int
    private(set) var columns: Int

    /// Visible screen lines, `rows` of them.
    private(set) var lines: [TerminalLine]
    /// Off-screen history above the visible region.
    private(set) var scrollback: [TerminalLine] = []
    let maxScrollback: Int

    /// Scroll region (DECSTBM); inclusive, 0-based.
    var scrollTop: Int
    var scrollBottom: Int

    init(rows: Int, columns: Int, maxScrollback: Int = 100_000) {
        self.rows = max(rows, 1)
        self.columns = max(columns, 1)
        self.maxScrollback = maxScrollback
        self.scrollTop = 0
        self.scrollBottom = self.rows - 1
        let width = self.columns
        self.lines = (0..<self.rows).map { _ in TerminalLine(width: width) }
    }

    private func blankCell(_ template: Cell) -> Cell {
        Cell.blank(background: template.background)
    }

    // MARK: - Access

    func line(at row: Int) -> TerminalLine {
        guard row >= 0 && row < rows else { return TerminalLine(width: columns) }
        return lines[row]
    }

    func cell(row: Int, column: Int) -> Cell {
        guard row >= 0, row < rows, column >= 0, column < columns else { return Cell() }
        return lines[row].cells[column]
    }

    // MARK: - Writing

    func setCell(_ cell: Cell, row: Int, column: Int) {
        guard row >= 0, row < rows, column >= 0, column < columns else { return }
        lines[row].cells[column] = cell
    }

    func setWrapped(_ wrapped: Bool, row: Int) {
        guard row >= 0, row < rows else { return }
        lines[row].wrapped = wrapped
    }

    // MARK: - Erase

    /// Erase from (row, column) to end of line.
    func eraseToLineEnd(row: Int, column: Int, template: Cell) {
        guard row >= 0, row < rows else { return }
        let blank = blankCell(template)
        for c in max(0, column)..<columns { lines[row].cells[c] = blank }
    }

    func eraseToLineStart(row: Int, column: Int, template: Cell) {
        guard row >= 0, row < rows else { return }
        let blank = blankCell(template)
        for c in 0...min(column, columns - 1) where c >= 0 { lines[row].cells[c] = blank }
    }

    func eraseLine(row: Int, template: Cell) {
        guard row >= 0, row < rows else { return }
        let blank = blankCell(template)
        for c in 0..<columns { lines[row].cells[c] = blank }
        lines[row].wrapped = false
    }

    func eraseDisplayBelow(row: Int, column: Int, template: Cell) {
        eraseToLineEnd(row: row, column: column, template: template)
        guard row + 1 < rows else { return }
        for r in (row + 1)..<rows { eraseLine(row: r, template: template) }
    }

    func eraseDisplayAbove(row: Int, column: Int, template: Cell) {
        eraseToLineStart(row: row, column: column, template: template)
        for r in 0..<row { eraseLine(row: r, template: template) }
    }

    func eraseDisplayAll(template: Cell) {
        for r in 0..<rows { eraseLine(row: r, template: template) }
    }

    /// Clear screen and push current contents into scrollback (used by `clear`).
    func eraseDisplayAndScrollback(template: Cell) {
        scrollback.removeAll(keepingCapacity: true)
        eraseDisplayAll(template: template)
    }

    // MARK: - Character editing within a line

    func insertBlanks(count: Int, row: Int, column: Int, template: Cell) {
        guard row >= 0, row < rows, count > 0 else { return }
        let blank = blankCell(template)
        var cells = lines[row].cells
        for _ in 0..<count { cells.insert(blank, at: min(column, cells.count)) }
        cells.removeLast(min(count, max(0, cells.count - columns)))
        if cells.count > columns { cells.removeLast(cells.count - columns) }
        lines[row].cells = cells
    }

    func deleteChars(count: Int, row: Int, column: Int, template: Cell) {
        guard row >= 0, row < rows, count > 0, column < columns else { return }
        let blank = blankCell(template)
        var cells = lines[row].cells
        let removable = min(count, cells.count - column)
        if removable > 0 { cells.removeSubrange(column..<(column + removable)) }
        while cells.count < columns { cells.append(blank) }
        lines[row].cells = cells
    }

    // MARK: - Scrolling

    /// Scroll the scroll-region up by `count` lines, pushing lines above the
    /// scroll region's top into scrollback only when the region spans the full
    /// screen (matching standard terminal history behaviour).
    func scrollUp(count: Int, template: Cell) {
        guard count > 0 else { return }
        let blank = blankCell(template)
        for _ in 0..<count {
            if scrollTop == 0 && scrollBottom == rows - 1 {
                appendToScrollback(lines[0])
            }
            lines.remove(at: scrollTop)
            var newLine = TerminalLine(width: columns, blank: blank)
            newLine.cells = Array(repeating: blank, count: columns)
            lines.insert(newLine, at: scrollBottom)
        }
    }

    func scrollDown(count: Int, template: Cell) {
        guard count > 0 else { return }
        let blank = blankCell(template)
        for _ in 0..<count {
            lines.remove(at: scrollBottom)
            var newLine = TerminalLine(width: columns, blank: blank)
            newLine.cells = Array(repeating: blank, count: columns)
            lines.insert(newLine, at: scrollTop)
        }
    }

    func insertLines(count: Int, row: Int, template: Cell) {
        guard row >= scrollTop, row <= scrollBottom else { return }
        let blank = blankCell(template)
        for _ in 0..<count {
            lines.remove(at: scrollBottom)
            var newLine = TerminalLine(width: columns, blank: blank)
            newLine.cells = Array(repeating: blank, count: columns)
            lines.insert(newLine, at: row)
        }
    }

    func deleteLines(count: Int, row: Int, template: Cell) {
        guard row >= scrollTop, row <= scrollBottom else { return }
        let blank = blankCell(template)
        for _ in 0..<count {
            lines.remove(at: row)
            var newLine = TerminalLine(width: columns, blank: blank)
            newLine.cells = Array(repeating: blank, count: columns)
            lines.insert(newLine, at: scrollBottom)
        }
    }

    private func appendToScrollback(_ line: TerminalLine) {
        scrollback.append(line)
        if scrollback.count > maxScrollback {
            scrollback.removeFirst(scrollback.count - maxScrollback)
        }
    }

    // MARK: - Resize

    func resize(rows newRows: Int, columns newCols: Int) {
        let newRows = max(newRows, 1)
        let newCols = max(newCols, 1)
        let blank = Cell()

        if newCols != columns {
            for i in lines.indices { lines[i].resize(to: newCols, blank: blank) }
            for i in scrollback.indices { scrollback[i].resize(to: newCols, blank: blank) }
        }

        if newRows > rows {
            // Pull lines back from scrollback if available, else add blanks at bottom.
            var added = newRows - rows
            var prepended: [TerminalLine] = []
            while added > 0, let last = scrollback.popLast() {
                prepended.insert(last, at: 0)
                added -= 1
            }
            lines.insert(contentsOf: prepended, at: 0)
            for _ in 0..<added { lines.append(TerminalLine(width: newCols, blank: blank)) }
        } else if newRows < rows {
            let remove = rows - newRows
            for _ in 0..<remove { appendToScrollback(lines.removeFirst()) }
        }

        rows = newRows
        columns = newCols
        scrollTop = 0
        scrollBottom = rows - 1
    }

    // MARK: - Snapshot for rendering

    /// All visible lines (no scrollback) as an immutable snapshot.
    func snapshotVisible() -> [TerminalLine] { lines }

    /// Total logical rows including scrollback.
    var totalRows: Int { scrollback.count + rows }

    /// Combined line accessor across scrollback + visible, index 0 = oldest.
    func combinedLine(at index: Int) -> TerminalLine {
        if index < scrollback.count { return scrollback[index] }
        let r = index - scrollback.count
        return r < rows ? lines[r] : TerminalLine(width: columns)
    }
}
