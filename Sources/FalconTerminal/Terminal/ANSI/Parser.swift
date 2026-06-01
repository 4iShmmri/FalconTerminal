import Foundation

/// A byte-stream VT parser implementing the VT100/VT220/xterm escape grammar.
///
/// It is a direct realisation of the VT500-series state machine: bytes are fed
/// in and dispatched to a `TerminalPerformer`. UTF-8 decoding happens inline in
/// the ground state so that multibyte and combining sequences print correctly.
final class Parser {
    private enum State {
        case ground
        case escape
        case escapeIntermediate
        case csiEntry
        case csiParam
        case csiIntermediate
        case csiIgnore
        case oscString
        case dcsEntry
        case dcsParam
        case dcsIntermediate
        case dcsPassthrough
        case dcsIgnore
        case sosPmApcString
    }

    private weak var performer: TerminalPerformer?
    private var state: State = .ground

    // Collected sequence pieces.
    private var params: [Int?] = []
    private var currentParam: Int?
    private var intermediates: [UInt8] = []
    private var oscBuffer: [UInt8] = []
    private var dcsBuffer: [UInt8] = []
    private var dcsFinal: UInt8 = 0

    // UTF-8 decode state for the ground path.
    private var utf8Remaining = 0
    private var utf8Accumulator: UInt32 = 0
    private var utf8Min: UInt32 = 0

    init(performer: TerminalPerformer) {
        self.performer = performer
    }

    func reset() {
        state = .ground
        clearSequence()
        oscBuffer.removeAll(keepingCapacity: true)
        dcsBuffer.removeAll(keepingCapacity: true)
        utf8Remaining = 0
    }

    private func clearSequence() {
        params.removeAll(keepingCapacity: true)
        currentParam = nil
        intermediates.removeAll(keepingCapacity: true)
    }

    // MARK: - Public feed

    func feed<S: Sequence>(_ bytes: S) where S.Element == UInt8 {
        for b in bytes { feed(b) }
    }

    func feed(_ byte: UInt8) {
        // C1 / control transitions valid from (almost) any state.
        switch byte {
        case 0x18, 0x1A: // CAN, SUB -> abort to ground
            if state != .oscString { performer?.execute(byte) }
            utf8Remaining = 0
            state = .ground
            return
        case 0x1B: // ESC
            if state == .oscString { finishOSC() }
            utf8Remaining = 0
            clearSequence()
            state = .escape
            return
        default:
            break
        }

        switch state {
        case .ground:            ground(byte)
        case .escape:            escape(byte)
        case .escapeIntermediate: escapeIntermediate(byte)
        case .csiEntry:          csiEntry(byte)
        case .csiParam:          csiParam(byte)
        case .csiIntermediate:   csiIntermediate(byte)
        case .csiIgnore:         csiIgnore(byte)
        case .oscString:         oscString(byte)
        case .dcsEntry:          dcsEntry(byte)
        case .dcsParam:          dcsParam(byte)
        case .dcsIntermediate:   dcsIntermediate(byte)
        case .dcsPassthrough:    dcsPassthrough(byte)
        case .dcsIgnore:         dcsIgnore(byte)
        case .sosPmApcString:    sosPmApcString(byte)
        }
    }

    // MARK: - Ground (printables + C0 + UTF-8)

    private func ground(_ byte: UInt8) {
        if utf8Remaining > 0 {
            decodeContinuation(byte)
            return
        }
        switch byte {
        case 0x00...0x17, 0x19, 0x1C...0x1F:
            performer?.execute(byte)
        case 0x20...0x7F:
            performer?.print(Unicode.Scalar(byte))
        case 0x80...0xBF:
            // Stray continuation byte: emit replacement and stay grounded.
            emitReplacement()
        case 0xC0...0xDF:
            beginUTF8(byte, length: 2, bits: UInt32(byte & 0x1F), min: 0x80)
        case 0xE0...0xEF:
            beginUTF8(byte, length: 3, bits: UInt32(byte & 0x0F), min: 0x800)
        case 0xF0...0xF7:
            beginUTF8(byte, length: 4, bits: UInt32(byte & 0x07), min: 0x10000)
        default:
            emitReplacement()
        }
    }

    private func beginUTF8(_ byte: UInt8, length: Int, bits: UInt32, min: UInt32) {
        utf8Accumulator = bits
        utf8Remaining = length - 1
        utf8Min = min
    }

    private func decodeContinuation(_ byte: UInt8) {
        guard (0x80...0xBF).contains(byte) else {
            // Invalid continuation: emit replacement, reprocess this byte.
            utf8Remaining = 0
            emitReplacement()
            feed(byte)
            return
        }
        utf8Accumulator = (utf8Accumulator << 6) | UInt32(byte & 0x3F)
        utf8Remaining -= 1
        if utf8Remaining == 0 {
            if utf8Accumulator < utf8Min || utf8Accumulator > 0x10FFFF
                || (0xD800...0xDFFF).contains(utf8Accumulator) {
                emitReplacement()
            } else if let scalar = Unicode.Scalar(utf8Accumulator) {
                performer?.print(scalar)
            } else {
                emitReplacement()
            }
        }
    }

    private func emitReplacement() {
        performer?.print(Unicode.Scalar(0xFFFD)!)
    }

    // MARK: - Escape

    private func escape(_ byte: UInt8) {
        switch byte {
        case 0x00...0x17, 0x19, 0x1C...0x1F:
            performer?.execute(byte)
        case 0x20...0x2F: // intermediate
            intermediates.append(byte)
            state = .escapeIntermediate
        case 0x5B: // [
            clearSequence()
            state = .csiEntry
        case 0x5D: // ]
            oscBuffer.removeAll(keepingCapacity: true)
            state = .oscString
        case 0x50: // P -> DCS
            clearSequence()
            dcsBuffer.removeAll(keepingCapacity: true)
            state = .dcsEntry
        case 0x58, 0x5E, 0x5F: // SOS, PM, APC
            state = .sosPmApcString
        case 0x30...0x4F, 0x51...0x57, 0x59, 0x5A, 0x5C, 0x60...0x7E:
            performer?.escDispatch(intermediates: intermediates, final: byte)
            state = .ground
        default:
            state = .ground
        }
    }

    private func escapeIntermediate(_ byte: UInt8) {
        switch byte {
        case 0x20...0x2F:
            intermediates.append(byte)
        case 0x30...0x7E:
            performer?.escDispatch(intermediates: intermediates, final: byte)
            state = .ground
        case 0x00...0x17, 0x19, 0x1C...0x1F:
            performer?.execute(byte)
        default:
            state = .ground
        }
    }

    // MARK: - CSI

    private func csiEntry(_ byte: UInt8) {
        switch byte {
        case 0x00...0x17, 0x19, 0x1C...0x1F:
            performer?.execute(byte)
        case 0x30...0x39: // digit
            appendDigit(byte); state = .csiParam
        case 0x3A: // ':' sub-parameter separator -> treat conservatively
            params.append(currentParam); currentParam = nil; state = .csiParam
        case 0x3B: // ';'
            params.append(currentParam); currentParam = nil; state = .csiParam
        case 0x3C...0x3F: // private markers < = > ?
            intermediates.append(byte); state = .csiParam
        case 0x20...0x2F: // intermediate
            intermediates.append(byte); state = .csiIntermediate
        case 0x40...0x7E: // final
            dispatchCSI(byte)
        default:
            state = .csiIgnore
        }
    }

    private func csiParam(_ byte: UInt8) {
        switch byte {
        case 0x00...0x17, 0x19, 0x1C...0x1F:
            performer?.execute(byte)
        case 0x30...0x39:
            appendDigit(byte)
        case 0x3A, 0x3B:
            params.append(currentParam); currentParam = nil
        case 0x3C...0x3F:
            intermediates.append(byte)
        case 0x20...0x2F:
            intermediates.append(byte); state = .csiIntermediate
        case 0x40...0x7E:
            dispatchCSI(byte)
        default:
            state = .csiIgnore
        }
    }

    private func csiIntermediate(_ byte: UInt8) {
        switch byte {
        case 0x00...0x17, 0x19, 0x1C...0x1F:
            performer?.execute(byte)
        case 0x20...0x2F:
            intermediates.append(byte)
        case 0x40...0x7E:
            dispatchCSI(byte)
        default:
            state = .csiIgnore
        }
    }

    private func csiIgnore(_ byte: UInt8) {
        if (0x40...0x7E).contains(byte) { state = .ground }
    }

    private func appendDigit(_ byte: UInt8) {
        let d = Int(byte - 0x30)
        currentParam = (currentParam ?? 0) * 10 + d
    }

    private func dispatchCSI(_ final: UInt8) {
        params.append(currentParam)
        currentParam = nil
        performer?.csiDispatch(parameters: params, intermediates: intermediates, final: final)
        clearSequence()
        state = .ground
    }

    // MARK: - OSC

    private func oscString(_ byte: UInt8) {
        switch byte {
        case 0x07: // BEL terminates
            finishOSC()
            state = .ground
        case 0x9C: // ST (C1)
            finishOSC()
            state = .ground
        default:
            oscBuffer.append(byte)
        }
    }

    private func finishOSC() {
        // Handle ESC \ (ST) by stripping a trailing 0x1B if present.
        if oscBuffer.last == 0x1B { oscBuffer.removeLast() }
        performer?.oscDispatch(oscBuffer)
        oscBuffer.removeAll(keepingCapacity: true)
    }

    // MARK: - DCS (collected, dispatched on ST)

    private func dcsEntry(_ byte: UInt8) {
        switch byte {
        case 0x30...0x39: appendDigit(byte); state = .dcsParam
        case 0x3B: params.append(currentParam); currentParam = nil; state = .dcsParam
        case 0x3C...0x3F: intermediates.append(byte); state = .dcsParam
        case 0x20...0x2F: intermediates.append(byte); state = .dcsIntermediate
        case 0x40...0x7E: dcsFinal = byte; state = .dcsPassthrough
        default: state = .dcsIgnore
        }
    }

    private func dcsParam(_ byte: UInt8) {
        switch byte {
        case 0x30...0x39: appendDigit(byte)
        case 0x3B: params.append(currentParam); currentParam = nil
        case 0x20...0x2F: intermediates.append(byte); state = .dcsIntermediate
        case 0x40...0x7E: dcsFinal = byte; state = .dcsPassthrough
        default: state = .dcsIgnore
        }
    }

    private func dcsIntermediate(_ byte: UInt8) {
        switch byte {
        case 0x20...0x2F: intermediates.append(byte)
        case 0x40...0x7E: dcsFinal = byte; state = .dcsPassthrough
        default: state = .dcsIgnore
        }
    }

    private func dcsPassthrough(_ byte: UInt8) {
        if byte == 0x9C { finishDCS(); state = .ground; return }
        dcsBuffer.append(byte)
    }

    private func dcsIgnore(_ byte: UInt8) {
        if byte == 0x9C { state = .ground }
    }

    private func finishDCS() {
        if dcsBuffer.last == 0x1B { dcsBuffer.removeLast() }
        params.append(currentParam)
        performer?.dcsDispatch(parameters: params, intermediates: intermediates, final: dcsFinal, data: dcsBuffer)
        dcsBuffer.removeAll(keepingCapacity: true)
        clearSequence()
    }

    private func sosPmApcString(_ byte: UInt8) {
        if byte == 0x9C { state = .ground }
        // Otherwise consume silently until ST / ESC \ .
    }
}
