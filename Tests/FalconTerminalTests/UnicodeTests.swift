import Testing
@testable import FalconTerminal

struct UnicodeTests {
    @Test("Arabic UTF-8 decodes into scalars")
    func arabic() {
        let h = Harness()
        h.feed("مرحبا")
        // 5 Arabic letters, each one column wide here.
        #expect(h.lineText(0) == "مرحبا")
    }

    @Test("Mixed Arabic, Latin, and emoji coexist")
    func mixed() {
        let h = Harness()
        h.feed("Hi مرحبا")
        #expect(h.lineText(0).contains("Hi"))
        #expect(h.lineText(0).contains("مرحبا"))
    }

    @Test("Wide CJK glyph occupies two columns")
    func wideCJK() {
        let h = Harness()
        h.feed("世X")
        #expect(h.cell(0, 0).attributes.contains(.wideLeader))
        #expect(h.cell(0, 1).attributes.contains(.wideTrailer))
        #expect(h.cell(0, 2).string == "X")
        #expect(h.cursor.column == 3)
    }

    @Test("Emoji is treated as wide")
    func emoji() {
        #expect(CharacterWidth.width(of: "🚀") == 2)
        #expect(CharacterWidth.width(of: "A") == 1)
    }

    @Test("Combining mark attaches to the previous cell")
    func combining() {
        let h = Harness()
        h.feed("e\u{0301}") // e + combining acute
        #expect(h.cell(0, 0).scalars.count == 2)
        #expect(h.cursor.column == 1)
    }

    @Test("Invalid UTF-8 yields the replacement character")
    func invalidUTF8() {
        let h = Harness()
        h.feed([0xC0, 0x80, 0x41]) // overlong + 'A'
        #expect(h.cell(0, 0).scalars.first == Unicode.Scalar(0xFFFD))
    }
}
