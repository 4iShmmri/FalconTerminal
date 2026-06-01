import Foundation

/// A terminal cell color. Either a reference to a palette slot (default / one of
/// the 256 indexed ANSI colors) or a direct 24-bit truecolor value.
///
/// Kept as a small value type so cells stay cheap to copy.
enum TerminalColor: Equatable, Hashable, Sendable {
    /// Use the theme's default foreground/background.
    case `default`
    /// One of the 256 xterm palette indices (0...255).
    case indexed(UInt8)
    /// A direct 24-bit color.
    case rgb(r: UInt8, g: UInt8, b: UInt8)

    var isDefault: Bool { self == .default }
}
