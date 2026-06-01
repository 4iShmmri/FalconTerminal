import SwiftUI

/// Wraps a single terminal surface, highlighting it when it is the active pane
/// within a multi-pane tab.
struct TerminalPaneView: View {
    @ObservedObject var pane: PaneModel
    @ObservedObject var tab: TerminalTab
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let theme = appState.theme
        let isActive = tab.activePaneID == pane.id
        let multiPane = tab.panes.count > 1

        TerminalView(
            session: pane.session,
            theme: theme,
            fontName: appState.fontName,
            fontSize: appState.fontSize,
            inlineSuggestions: appState.settings.inlineSuggestions,
            slashCommands: appState.settings.slashCommands,
            onFocus: { tab.activePaneID = pane.id },
            onSlashCommand: { appState.runCommand($0) }
        )
        .background(Color(theme.background))
        .overlay(
            Rectangle()
                .strokeBorder(
                    multiPane && isActive ? Color(theme.cursor).opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .contextMenu {
            Button("Split Vertically") { appState.splitActivePane(axis: .horizontal) }
            Button("Split Horizontally") { appState.splitActivePane(axis: .vertical) }
            Divider()
            Button("Close Pane") {
                tab.activePaneID = pane.id
                appState.closeActivePane()
            }
        }
    }
}
