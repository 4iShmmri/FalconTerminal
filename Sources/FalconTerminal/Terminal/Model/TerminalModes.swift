import Foundation

enum MouseTrackingMode: Sendable {
    case none
    case x10
    case normal      // 1000
    case button      // 1002
    case any         // 1003
}

enum MouseEncoding: Sendable {
    case x10
    case sgr         // 1006
}

/// DEC private and ANSI mode flags that affect emulation behaviour.
struct TerminalModes: Sendable {
    var autoWrap = true
    var applicationCursorKeys = false   // DECCKM (1)
    var applicationKeypad = false       // DECPAM / DECPNM
    var insertMode = false              // IRM (4)
    var originMode = false              // DECOM (6)
    var cursorVisible = true            // DECTCEM (25)
    var reverseVideo = false            // DECSCNM (5)
    var bracketedPaste = false          // 2004
    var altScreen = false               // 1049 / 47 / 1047
    var mouseTracking: MouseTrackingMode = .none
    var mouseEncoding: MouseEncoding = .x10
    var focusReporting = false          // 1004
}
