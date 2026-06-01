import SwiftUI

/// Menu bar commands and their keyboard shortcuts.
struct TerminalCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        // File / tab management.
        CommandGroup(replacing: .newItem) {
            Button("New Tab") { appState.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("New Window") { appState.newTab() }
                .keyboardShortcut("n", modifiers: .command)
            Divider()
            Button("Close Tab") { appState.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
            Button("Duplicate Tab") { appState.duplicateActiveTab() }
                .keyboardShortcut("t", modifiers: [.command, .option])
        }

        // Splits.
        CommandMenu("Pane") {
            Button("Split Vertically") { appState.splitActivePane(axis: .horizontal) }
                .keyboardShortcut("d", modifiers: .command)
            Button("Split Horizontally") { appState.splitActivePane(axis: .vertical) }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Divider()
            Button("Close Pane") { appState.closeActivePane() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        // Navigation.
        CommandMenu("Navigate") {
            Button("Command Palette…") { appState.showCommandPalette = true }
                .keyboardShortcut("k", modifiers: .command)
            Divider()
            Button("Next Tab") { appState.selectNextTab() }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("Previous Tab") { appState.selectPreviousTab() }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Divider()
            Button("Toggle SSH Sidebar") { appState.showSSHSidebar.toggle() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        // View / appearance.
        CommandGroup(after: .toolbar) {
            Button("Increase Font Size") { appState.adjustFontSize(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Decrease Font Size") { appState.adjustFontSize(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
        }
    }
}
