import Foundation

/// Metadata for a slash command shown in the command palette.
struct PaletteCommand: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    /// Alternate names that also trigger this command.
    let aliases: [String]
    let usage: String
    let summary: String
    /// True if the command takes a free-text argument (so the palette keeps the
    /// rest of the line as one argument).
    let takesArgument: Bool

    func matches(_ token: String) -> Bool {
        let t = token.lowercased()
        return name.hasPrefix(t) || aliases.contains { $0.hasPrefix(t) }
    }

    /// The full catalog of available commands.
    static let all: [PaletteCommand] = [
        PaletteCommand(name: "new", aliases: ["tab"], usage: "/new [name]",
                       summary: "Open a new tab, optionally named", takesArgument: true),
        PaletteCommand(name: "rename", aliases: ["name"], usage: "/rename <name>",
                       summary: "Rename the active tab", takesArgument: true),
        PaletteCommand(name: "close", aliases: ["closetab"], usage: "/close",
                       summary: "Close the active tab", takesArgument: false),
        PaletteCommand(name: "duplicate", aliases: ["dup"], usage: "/duplicate",
                       summary: "Duplicate the active tab", takesArgument: false),
        PaletteCommand(name: "split", aliases: ["vsplit", "v"], usage: "/split",
                       summary: "Split the active pane vertically", takesArgument: false),
        PaletteCommand(name: "hsplit", aliases: ["h"], usage: "/hsplit",
                       summary: "Split the active pane horizontally", takesArgument: false),
        PaletteCommand(name: "closepane", aliases: ["killpane"], usage: "/closepane",
                       summary: "Close the active pane", takesArgument: false),
        PaletteCommand(name: "ssh", aliases: ["connect"], usage: "/ssh <host>",
                       summary: "Connect to a saved SSH host", takesArgument: true),
        PaletteCommand(name: "theme", aliases: [], usage: "/theme <name>",
                       summary: "Switch the color theme", takesArgument: true),
        PaletteCommand(name: "font", aliases: ["fontsize"], usage: "/font <size>",
                       summary: "Set the font size", takesArgument: true),
        PaletteCommand(name: "clear", aliases: ["cls"], usage: "/clear",
                       summary: "Clear the active terminal", takesArgument: false),
        PaletteCommand(name: "sidebar", aliases: ["ssh-sidebar"], usage: "/sidebar",
                       summary: "Toggle the SSH sidebar", takesArgument: false)
    ]
}
