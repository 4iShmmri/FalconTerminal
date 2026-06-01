import Testing
@testable import FalconTerminal

struct EmulatorTests {
    @Test("Autowrap moves to the next line at the right margin")
    func autowrap() {
        let h = Harness(rows: 4, columns: 4)
        h.feed("abcde")
        #expect(h.lineText(0) == "abcd")
        #expect(h.lineText(1) == "e")
        #expect(h.cursor.row == 1)
        #expect(h.cursor.column == 1)
    }

    @Test("Alternate screen switches buffers and restores on exit")
    func altScreen() {
        let h = Harness(rows: 4, columns: 10)
        h.feed("main")
        h.feed("\u{1b}[?1049h")          // enter alt screen
        h.feed("\u{1b}[2J\u{1b}[Halt")   // clear + home + write
        #expect(h.lineText(0) == "alt")
        h.feed("\u{1b}[?1049l")          // leave alt screen
        #expect(h.lineText(0) == "main")
    }

    @Test("Scroll region constrains line feeds")
    func scrollRegion() {
        let h = Harness(rows: 5, columns: 8)
        h.feed("\u{1b}[2;3r")  // region rows 2..3
        h.feed("\u{1b}[2;1HX") // row 2
        h.feed("\r\nY")        // row 3
        h.feed("\r\nZ")        // should scroll within region
        #expect(h.cursor.row == 2) // stays at region bottom (0-based row 2)
    }

    @Test("Insert mode shifts existing characters right")
    func insertMode() {
        let h = Harness(rows: 2, columns: 10)
        h.feed("ABCD")
        h.feed("\u{1b}[1G")     // column 1
        h.feed("\u{1b}[4h")     // insert mode on
        h.feed("X")
        #expect(h.lineText(0) == "XABCD")
    }

    @Test("Reset (RIS) clears the screen and state")
    func reset() {
        let h = Harness(rows: 3, columns: 5)
        h.feed("\u{1b}[31mhi")
        h.feed("\u{1b}c")
        #expect(h.lineText(0) == "")
        #expect(h.cursor.foreground == .default)
    }
}
