import Testing
@testable import FalconTerminal

struct BufferTests {
    @Test("Scrolling past the bottom pushes lines into scrollback")
    func scrollback() {
        let buffer = TerminalBuffer(rows: 3, columns: 10)
        let template = Cell()
        // Fill row 0 with a marker, then scroll up.
        for (i, ch) in "TOP".unicodeScalars.enumerated() {
            buffer.setCell(Cell(scalars: [ch]), row: 0, column: i)
        }
        buffer.scrollUp(count: 1, template: template)
        #expect(buffer.scrollback.count == 1)
        #expect(buffer.scrollback[0].plainText == "TOP")
    }

    @Test("Insert and delete characters shift the line")
    func insertDelete() {
        let buffer = TerminalBuffer(rows: 2, columns: 6)
        for (i, ch) in "abcdef".unicodeScalars.enumerated() {
            buffer.setCell(Cell(scalars: [ch]), row: 0, column: i)
        }
        buffer.deleteChars(count: 2, row: 0, column: 1, template: Cell())
        #expect(buffer.line(at: 0).plainText == "adef")
    }

    @Test("Resize narrower trims columns; wider pads them")
    func resize() {
        let buffer = TerminalBuffer(rows: 2, columns: 4)
        for (i, ch) in "abcd".unicodeScalars.enumerated() {
            buffer.setCell(Cell(scalars: [ch]), row: 0, column: i)
        }
        buffer.resize(rows: 2, columns: 2)
        #expect(buffer.columns == 2)
        #expect(buffer.line(at: 0).plainText == "ab")
        buffer.resize(rows: 2, columns: 6)
        #expect(buffer.columns == 6)
    }

    @Test("Insert lines within the scroll region")
    func insertLines() {
        let buffer = TerminalBuffer(rows: 4, columns: 4)
        for r in 0..<4 {
            buffer.setCell(Cell(scalars: [Unicode.Scalar(UInt8(48 + r))]), row: r, column: 0)
        }
        buffer.insertLines(count: 1, row: 1, template: Cell())
        #expect(buffer.line(at: 0).plainText == "0")
        #expect(buffer.line(at: 1).plainText == "")
        #expect(buffer.line(at: 2).plainText == "1")
    }
}
