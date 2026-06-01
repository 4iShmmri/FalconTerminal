import Foundation
@testable import FalconTerminal

/// Builds an emulator + parser and feeds a string, returning helpers to read
/// the resulting grid in tests.
final class Harness {
    let emulator: TerminalEmulator
    let parser: Parser

    init(rows: Int = 24, columns: Int = 80) {
        emulator = TerminalEmulator(rows: rows, columns: columns)
        parser = Parser(performer: emulator)
    }

    func feed(_ string: String) {
        parser.feed(Array(string.utf8))
    }

    func feed(_ bytes: [UInt8]) {
        parser.feed(bytes)
    }

    func lineText(_ row: Int) -> String {
        emulator.buffer.line(at: row).plainText
    }

    func cell(_ row: Int, _ col: Int) -> Cell {
        emulator.buffer.cell(row: row, column: col)
    }

    var cursor: Cursor { emulator.cursor }
}
