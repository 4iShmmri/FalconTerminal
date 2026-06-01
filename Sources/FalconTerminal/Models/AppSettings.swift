import Foundation

/// User-facing preferences persisted across launches.
struct AppSettings: Codable, Sendable, Equatable {
    var themeName: String = "Falcon Dark"
    var fontName: String = "SFMono-Regular"
    var fontSize: Double = 11
    var restoreSessionsOnLaunch: Bool = true
    var defaultShellPath: String = Shell.defaultShell()
    var cursorStyle: String = "block"          // block | bar | underline
    var scrollbackLines: Int = 100_000
    var audibleBell: Bool = true
    var inlineSuggestions: Bool = true
    /// Intercept `/command` lines typed at the prompt and run them as app
    /// actions instead of sending them to the shell.
    var slashCommands: Bool = true

    static let `default` = AppSettings()

    var fontSizeCG: Double { max(8, min(fontSize, 48)) }

    var resolvedCursorStyle: CursorStyle {
        switch cursorStyle {
        case "bar": return .bar
        case "underline": return .underline
        default: return .block
        }
    }
}

/// Available monospace fonts the UI offers.
enum FontCatalog {
    static let recommended: [String] = [
        "SFMono-Regular",
        "JetBrains Mono",
        "Menlo",
        "Fira Code",
        "Cascadia Code",
        "Monaco"
    ]

    /// Only those actually installed (SF Mono / Menlo / Monaco are stock).
    static func available() -> [String] {
        let installed = Set(NSFontManagerShim.availableFontFamilies())
        return recommended.filter { name in
            installed.contains(name) || NSFontExists(name)
        }
    }
}

import AppKit

private func NSFontExists(_ name: String) -> Bool {
    NSFont(name: name, size: 12) != nil
}

private enum NSFontManagerShim {
    static func availableFontFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies
    }
}
