import Foundation

/// CSI (Control Sequence Introducer) dispatch: cursor movement, erasing,
/// line/character editing, scroll regions, SGR, mode set/reset, and reports.
extension TerminalEmulator {
    func csiDispatch(parameters: [Int?], intermediates: [UInt8], final: UInt8) {
        let isPrivate = intermediates.contains(0x3F) // '?'
        let isGreater = intermediates.contains(0x3E) // '>'

        func p(_ index: Int, default def: Int = 0) -> Int {
            guard index < parameters.count else { return def }
            return parameters[index] ?? def
        }
        func pPositive(_ index: Int) -> Int { max(1, p(index, default: 1)) }

        switch final {
        // Cursor movement
        case 0x41: moveCursor(rowDelta: -pPositive(0))                       // CUU
        case 0x42: moveCursor(rowDelta: pPositive(0))                        // CUD
        case 0x43: moveCursor(colDelta: pPositive(0))                        // CUF
        case 0x44: moveCursor(colDelta: -pPositive(0))                       // CUB
        case 0x45: carriageReturn(); moveCursor(rowDelta: pPositive(0))      // CNL
        case 0x46: carriageReturn(); moveCursor(rowDelta: -pPositive(0))     // CPL
        case 0x47: setColumn(p(0, default: 1) - 1)                           // CHA
        case 0x48, 0x66:                                                     // CUP / HVP
            setPosition(row: p(0, default: 1) - 1, column: p(1, default: 1) - 1)
        case 0x64: setRow(p(0, default: 1) - 1)                              // VPA
        case 0x65: moveCursor(rowDelta: pPositive(0))                        // VPR
        case 0x60: setColumn(p(0, default: 1) - 1)                           // HPA

        // Tabs
        case 0x49: tabForward(count: pPositive(0))                           // CHT
        case 0x5A: tabBackward(count: pPositive(0))                          // CBT
        case 0x67: clearTabStop(mode: p(0))                                  // TBC

        // Erase
        case 0x4A: eraseDisplay(mode: p(0))                                  // ED
        case 0x4B: eraseLine(mode: p(0))                                     // EL
        case 0x58: eraseChars(count: pPositive(0))                          // ECH

        // Insert / delete
        case 0x40: buffer.insertBlanks(count: pPositive(0), row: cursor.row, column: cursor.column, template: templateCell) // ICH
        case 0x50: buffer.deleteChars(count: pPositive(0), row: cursor.row, column: cursor.column, template: templateCell)  // DCH
        case 0x4C: buffer.insertLines(count: pPositive(0), row: cursor.row, template: templateCell)  // IL
        case 0x4D: buffer.deleteLines(count: pPositive(0), row: cursor.row, template: templateCell)  // DL

        // Scroll
        case 0x53: buffer.scrollUp(count: pPositive(0), template: templateCell)    // SU
        case 0x54: buffer.scrollDown(count: pPositive(0), template: templateCell)  // SD

        // SGR
        case 0x6D:
            if isGreater { break } // xterm key-modifier options — ignore
            SGR.apply(parameters: parameters, to: &cursor)

        // Modes
        case 0x68: setModes(parameters: parameters, isPrivate: isPrivate, enable: true)   // SM / DECSET
        case 0x6C: setModes(parameters: parameters, isPrivate: isPrivate, enable: false)  // RM / DECRST

        // Scroll region (DECSTBM)
        case 0x72 where !isPrivate:
            setScrollRegion(top: p(0, default: 1) - 1, bottom: p(1, default: rows) - 1)

        // Save / restore cursor
        case 0x73 where !isPrivate: saveCursor()                            // SCOSC
        case 0x75 where !isPrivate: restoreCursor()                         // SCORC

        // Reports
        case 0x63: deviceAttributes(isGreater: isGreater)                   // DA
        case 0x6E: deviceStatusReport(mode: p(0), isPrivate: isPrivate)     // DSR

        default:
            break
        }
    }

    // MARK: - Movement helpers

    private func moveCursor(rowDelta: Int = 0, colDelta: Int = 0) {
        cursor.row = clampRow(cursor.row + rowDelta)
        cursor.column = max(0, min(cursor.column + colDelta, columns - 1))
        cursor.wrapPending = false
    }

    private func setColumn(_ col: Int) {
        cursor.column = max(0, min(col, columns - 1))
        cursor.wrapPending = false
    }

    private func setRow(_ row: Int) {
        cursor.row = clampRow(row + originRowOffset)
        cursor.wrapPending = false
    }

    private func setPosition(row: Int, column: Int) {
        cursor.row = clampRow(row + originRowOffset)
        cursor.column = max(0, min(column, columns - 1))
        cursor.wrapPending = false
    }

    private var originRowOffset: Int { modes.originMode ? buffer.scrollTop : 0 }

    private func clampRow(_ row: Int) -> Int {
        if modes.originMode {
            return max(buffer.scrollTop, min(row, buffer.scrollBottom))
        }
        return max(0, min(row, rows - 1))
    }

    // MARK: - Tabs

    private func tabForward(count: Int) {
        for _ in 0..<count { horizontalTab() }
    }

    private func tabBackward(count: Int) {
        for _ in 0..<count {
            var c = cursor.column - 1
            while c > 0 && !tabStopSet.contains(c) { c -= 1 }
            cursor.column = max(0, c)
        }
    }

    private var tabStopSet: Set<Int> {
        var set: Set<Int> = []
        var c = 0
        while c < columns { set.insert(c); c += 8 }
        return set
    }

    private func clearTabStop(mode: Int) {
        // Tab stops are derived (every 8 cols); TBC is accepted as a no-op
        // for the common default-stops case used by all standard tools.
    }

    // MARK: - Erase

    private func eraseDisplay(mode: Int) {
        switch mode {
        case 0: buffer.eraseDisplayBelow(row: cursor.row, column: cursor.column, template: templateCell)
        case 1: buffer.eraseDisplayAbove(row: cursor.row, column: cursor.column, template: templateCell)
        case 2: buffer.eraseDisplayAll(template: templateCell)
        case 3: buffer.eraseDisplayAndScrollback(template: templateCell)
        default: break
        }
    }

    private func eraseLine(mode: Int) {
        switch mode {
        case 0: buffer.eraseToLineEnd(row: cursor.row, column: cursor.column, template: templateCell)
        case 1: buffer.eraseToLineStart(row: cursor.row, column: cursor.column, template: templateCell)
        case 2: buffer.eraseLine(row: cursor.row, template: templateCell)
        default: break
        }
    }

    private func eraseChars(count: Int) {
        let end = min(cursor.column + count, columns)
        let blank = Cell.blank(background: cursor.background)
        for c in cursor.column..<end { buffer.setCell(blank, row: cursor.row, column: c) }
    }

    // MARK: - Scroll region

    private func setScrollRegion(top: Int, bottom: Int) {
        let t = max(0, top)
        let b = bottom < 0 ? rows - 1 : min(bottom, rows - 1)
        guard t < b else { return }
        buffer.scrollTop = t
        buffer.scrollBottom = b
        // DECSTBM homes the cursor (respecting origin mode).
        cursor.row = modes.originMode ? t : 0
        cursor.column = 0
        cursor.wrapPending = false
    }

    // MARK: - Modes

    private func setModes(parameters: [Int?], isPrivate: Bool, enable: Bool) {
        for raw in parameters {
            guard let mode = raw else { continue }
            if isPrivate { setPrivateMode(mode, enable: enable) }
            else { setAnsiMode(mode, enable: enable) }
        }
    }

    private func setAnsiMode(_ mode: Int, enable: Bool) {
        switch mode {
        case 4: modes.insertMode = enable   // IRM
        default: break
        }
    }

    private func setPrivateMode(_ mode: Int, enable: Bool) {
        switch mode {
        case 1:  modes.applicationCursorKeys = enable
        case 5:  modes.reverseVideo = enable
        case 6:  modes.originMode = enable; cursor.row = clampRow(0); cursor.column = 0
        case 7:  modes.autoWrap = enable
        case 25: modes.cursorVisible = enable; cursor.visible = enable
        case 1000: modes.mouseTracking = enable ? .normal : .none
        case 1002: modes.mouseTracking = enable ? .button : .none
        case 1003: modes.mouseTracking = enable ? .any : .none
        case 1004: modes.focusReporting = enable
        case 1006: modes.mouseEncoding = enable ? .sgr : .x10
        case 2004: modes.bracketedPaste = enable
        case 47, 1047:
            if enable { enableAltScreen(clear: false) } else { disableAltScreen() }
        case 1049:
            if enable { enableAltScreen(clear: true) } else { disableAltScreen() }
        default:
            break
        }
    }

    // MARK: - Reports

    private func deviceAttributes(isGreater: Bool) {
        if isGreater {
            // Secondary DA: report as VT220.
            onRespond?("\u{1b}[>1;95;0c")
        } else {
            // Primary DA: VT100 with Advanced Video Option.
            onRespond?("\u{1b}[?1;2c")
        }
    }

    private func deviceStatusReport(mode: Int, isPrivate: Bool) {
        switch mode {
        case 5:
            onRespond?("\u{1b}[0n") // terminal OK
        case 6:
            let row = (modes.originMode ? cursor.row - buffer.scrollTop : cursor.row) + 1
            let col = cursor.column + 1
            onRespond?("\u{1b}[\(row);\(col)R")
        default:
            break
        }
    }
}
