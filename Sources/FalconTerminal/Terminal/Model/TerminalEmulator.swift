import Foundation

/// Drives a `TerminalBuffer` from parsed VT sequences. Implements
/// `TerminalPerformer`, so a `Parser` feeds bytes straight into it.
///
/// Owns the main + alternate screens, the cursor, the tab stops, and the DEC
/// mode flags. Emits side effects (title, bell, host responses) through
/// closures wired up by the owning session.
final class TerminalEmulator: TerminalPerformer {
    private(set) var main: TerminalBuffer
    private(set) var alt: TerminalBuffer
    var buffer: TerminalBuffer

    var cursor = Cursor()
    private var savedCursor = Cursor()
    private var savedCursorAlt = Cursor()

    var modes = TerminalModes()
    private var tabStops: Set<Int> = []

    var title: String = ""

    // Side-effect hooks (set by the session).
    var onTitleChange: ((String) -> Void)?
    var onBell: (() -> Void)?
    var onRespond: ((String) -> Void)?
    var onUpdate: (() -> Void)?

    init(rows: Int, columns: Int, maxScrollback: Int = 100_000) {
        main = TerminalBuffer(rows: rows, columns: columns, maxScrollback: maxScrollback)
        alt = TerminalBuffer(rows: rows, columns: columns, maxScrollback: 0)
        buffer = main
        resetTabStops(columns: columns)
    }

    var rows: Int { buffer.rows }
    var columns: Int { buffer.columns }

    func resize(rows: Int, columns: Int) {
        main.resize(rows: rows, columns: columns)
        alt.resize(rows: rows, columns: columns)
        cursor.row = min(cursor.row, rows - 1)
        cursor.column = min(cursor.column, columns - 1)
        cursor.wrapPending = false
        resetTabStops(columns: columns)
    }

    private func resetTabStops(columns: Int) {
        tabStops.removeAll()
        var c = 0
        while c < columns { tabStops.insert(c); c += 8 }
    }

    /// Template cell carrying the cursor's current background so erases fill
    /// with the active background color (xterm "background color erase").
    var templateCell: Cell {
        Cell(scalars: [" "], foreground: cursor.foreground, background: cursor.background, attributes: [])
    }

    // MARK: - TerminalPerformer: print

    func print(_ scalar: Unicode.Scalar) {
        let w = CharacterWidth.width(of: scalar)

        // Combining mark: attach to the previously written cell.
        if w == 0 {
            attachCombining(scalar)
            return
        }

        if cursor.wrapPending && modes.autoWrap {
            carriageReturn()
            lineFeed()
            cursor.wrapPending = false
        }

        // A wide glyph that won't fit: wrap (or clamp) first.
        if w == 2 && cursor.column == columns - 1 {
            if modes.autoWrap {
                buffer.setWrapped(true, row: cursor.row)
                carriageReturn()
                lineFeed()
            }
        }

        if modes.insertMode {
            buffer.insertBlanks(count: w, row: cursor.row, column: cursor.column, template: templateCell)
        }

        var cell = Cell(
            scalars: [scalar],
            foreground: cursor.foreground,
            background: cursor.background,
            attributes: cursor.attributes
        )
        if w == 2 { cell.attributes.insert(.wideLeader) }
        buffer.setCell(cell, row: cursor.row, column: cursor.column)

        if w == 2 && cursor.column + 1 < columns {
            var trailer = Cell(
                scalars: [" "],
                foreground: cursor.foreground,
                background: cursor.background,
                attributes: cursor.attributes
            )
            trailer.attributes.insert(.wideTrailer)
            buffer.setCell(trailer, row: cursor.row, column: cursor.column + 1)
        }

        advanceCursor(by: w)
    }

    private func attachCombining(_ scalar: Unicode.Scalar) {
        var col = cursor.column - 1
        if col < 0 { col = 0 }
        guard cursor.row >= 0, cursor.row < rows else { return }
        var cell = buffer.cell(row: cursor.row, column: col)
        cell.scalars.append(scalar)
        buffer.setCell(cell, row: cursor.row, column: col)
    }

    private func advanceCursor(by width: Int) {
        let next = cursor.column + width
        if next >= columns {
            cursor.column = columns - 1
            cursor.wrapPending = true
        } else {
            cursor.column = next
            cursor.wrapPending = false
        }
    }

    // MARK: - TerminalPerformer: execute (C0)

    func execute(_ control: UInt8) {
        switch control {
        case 0x07: onBell?()                 // BEL
        case 0x08: backspace()               // BS
        case 0x09: horizontalTab()           // HT
        case 0x0A, 0x0B, 0x0C:               // LF, VT, FF
            lineFeed()
        case 0x0D: carriageReturn()          // CR
        case 0x0E, 0x0F: break               // SO / SI (charset shift) — ignored
        default: break
        }
    }

    func backspace() {
        if cursor.wrapPending {
            cursor.wrapPending = false
        } else if cursor.column > 0 {
            cursor.column -= 1
        }
    }

    func horizontalTab() {
        var c = cursor.column + 1
        while c < columns && !tabStops.contains(c) { c += 1 }
        cursor.column = min(c, columns - 1)
        cursor.wrapPending = false
    }

    func carriageReturn() {
        cursor.column = 0
        cursor.wrapPending = false
    }

    func lineFeed() {
        if cursor.row == buffer.scrollBottom {
            buffer.scrollUp(count: 1, template: templateCell)
        } else if cursor.row < rows - 1 {
            cursor.row += 1
        }
        cursor.wrapPending = false
    }

    func reverseIndex() {
        if cursor.row == buffer.scrollTop {
            buffer.scrollDown(count: 1, template: templateCell)
        } else if cursor.row > 0 {
            cursor.row -= 1
        }
    }

    // MARK: - TerminalPerformer: ESC dispatch

    func escDispatch(intermediates: [UInt8], final: UInt8) {
        if intermediates.isEmpty {
            switch final {
            case 0x37: saveCursor()                    // ESC 7 (DECSC)
            case 0x38: restoreCursor()                 // ESC 8 (DECRC)
            case 0x44: lineFeed()                      // ESC D (IND)
            case 0x45: carriageReturn(); lineFeed()    // ESC E (NEL)
            case 0x4D: reverseIndex()                  // ESC M (RI)
            case 0x48: tabStops.insert(cursor.column)  // ESC H (HTS)
            case 0x63: fullReset()                     // ESC c (RIS)
            case 0x3D: modes.applicationKeypad = true  // ESC = (DECKPAM)
            case 0x3E: modes.applicationKeypad = false // ESC > (DECKPNM)
            default: break
            }
        }
        // Charset designations (ESC ( B etc.) are accepted and ignored:
        // we always render Unicode, so the special graphics set is unused.
    }

    // MARK: - TerminalPerformer: OSC dispatch

    func oscDispatch(_ data: [UInt8]) {
        guard let str = String(bytes: data, encoding: .utf8) else { return }
        // Format: <code>;<payload>
        guard let sep = str.firstIndex(of: ";") else { return }
        let code = String(str[str.startIndex..<sep])
        let payload = String(str[str.index(after: sep)...])
        switch code {
        case "0", "2":
            title = payload
            onTitleChange?(payload)
        case "1":
            break // icon name — ignored
        default:
            break
        }
    }

    func dcsDispatch(parameters: [Int?], intermediates: [UInt8], final: UInt8, data: [UInt8]) {
        // DCS sequences (e.g. sixel, DECRQSS) are accepted and ignored for now.
    }

    // MARK: - Cursor save/restore

    func saveCursor() {
        if modes.altScreen { savedCursorAlt = cursor } else { savedCursor = cursor }
    }

    func restoreCursor() {
        cursor = modes.altScreen ? savedCursorAlt : savedCursor
        clampCursor()
    }

    func clampCursor() {
        cursor.row = max(0, min(cursor.row, rows - 1))
        cursor.column = max(0, min(cursor.column, columns - 1))
    }

    // MARK: - Reset

    func fullReset() {
        modes = TerminalModes()
        cursor = Cursor()
        savedCursor = Cursor()
        savedCursorAlt = Cursor()
        buffer = main
        main.eraseDisplayAndScrollback(template: Cell())
        alt.eraseDisplayAll(template: Cell())
        resetTabStops(columns: columns)
    }

    // MARK: - Alternate screen

    func enableAltScreen(clear: Bool) {
        guard !modes.altScreen else { return }
        saveCursor()
        modes.altScreen = true
        buffer = alt
        if clear { alt.eraseDisplayAll(template: templateCell) }
    }

    func disableAltScreen() {
        guard modes.altScreen else { return }
        modes.altScreen = false
        buffer = main
        restoreCursor()
    }
}
