import Testing
@testable import FalconTerminal

struct ParserTests {
    @Test("Plain text prints into the grid")
    func plainText() {
        let h = Harness()
        h.feed("hello")
        #expect(h.lineText(0) == "hello")
        #expect(h.cursor.column == 5)
        #expect(h.cursor.row == 0)
    }

    @Test("Carriage return and line feed move the cursor")
    func crlf() {
        let h = Harness()
        h.feed("ab\r\ncd")
        #expect(h.lineText(0) == "ab")
        #expect(h.lineText(1) == "cd")
        #expect(h.cursor.row == 1)
        #expect(h.cursor.column == 2)
    }

    @Test("Backspace moves the cursor left without erasing")
    func backspace() {
        let h = Harness()
        h.feed("abc\u{08}")
        #expect(h.cursor.column == 2)
        #expect(h.lineText(0) == "abc")
    }

    @Test("SGR sets foreground color and bold")
    func sgrColors() {
        let h = Harness()
        h.feed("\u{1b}[1;31mR\u{1b}[0mX")
        let r = h.cell(0, 0)
        #expect(r.foreground == .indexed(1))
        #expect(r.attributes.contains(.bold))
        let x = h.cell(0, 1)
        #expect(x.foreground == .default)
        #expect(!x.attributes.contains(.bold))
    }

    @Test("Truecolor SGR sets an RGB foreground")
    func truecolor() {
        let h = Harness()
        h.feed("\u{1b}[38;2;10;20;30mZ")
        #expect(h.cell(0, 0).foreground == .rgb(r: 10, g: 20, b: 30))
    }

    @Test("CUP positions the cursor (1-based)")
    func cursorPosition() {
        let h = Harness()
        h.feed("\u{1b}[5;10HX")
        #expect(h.cursor.row == 4)
        #expect(h.cell(4, 9).string == "X")
    }

    @Test("Erase in line clears to end")
    func eraseLine() {
        let h = Harness()
        h.feed("hello\u{1b}[3G\u{1b}[K")  // move to col 3, erase to EOL
        #expect(h.lineText(0) == "he")
    }

    @Test("Erase display clears the screen")
    func eraseDisplay() {
        let h = Harness()
        h.feed("line1\r\nline2\u{1b}[2J")
        #expect(h.lineText(0) == "")
        #expect(h.lineText(1) == "")
    }

    @Test("OSC sets the window title")
    func oscTitle() {
        let h = Harness()
        var captured = ""
        h.emulator.onTitleChange = { captured = $0 }
        h.feed("\u{1b}]0;My Title\u{07}")
        #expect(captured == "My Title")
    }

    @Test("DSR cursor position report responds correctly")
    func cursorReport() {
        let h = Harness()
        var response = ""
        h.emulator.onRespond = { response += $0 }
        h.feed("\u{1b}[3;7H\u{1b}[6n")
        #expect(response == "\u{1b}[3;7R")
    }
}
