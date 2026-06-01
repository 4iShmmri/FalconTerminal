import Foundation

/// The set of actions a `Parser` dispatches as it decodes a byte stream.
/// `TerminalEmulator` implements this to mutate the screen buffer.
///
/// This mirrors the dispatch surface of the classic VT500 parser
/// (Paul Williams' state machine): printable text, C0/C1 execution, and the
/// escape / CSI / OSC / DCS dispatch families.
protocol TerminalPerformer: AnyObject {
    /// A printable grapheme scalar reached in the ground state.
    func print(_ scalar: Unicode.Scalar)

    /// Execute a C0 or C1 control code (e.g. BEL, BS, LF, CR).
    func execute(_ control: UInt8)

    /// Final-byte CSI dispatch with collected numeric parameters and any
    /// private-marker / intermediate bytes.
    func csiDispatch(parameters: [Int?], intermediates: [UInt8], final: UInt8)

    /// ESC dispatch (no CSI), e.g. ESC = , ESC > , ESC M , charset selection.
    func escDispatch(intermediates: [UInt8], final: UInt8)

    /// A completed OSC string (without the introducer / terminator).
    func oscDispatch(_ data: [UInt8])

    /// A completed DCS string payload (introducer params + body).
    func dcsDispatch(parameters: [Int?], intermediates: [UInt8], final: UInt8, data: [UInt8])
}
