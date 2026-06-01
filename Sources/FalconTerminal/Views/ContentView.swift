import SwiftUI

/// The main window: optional SSH sidebar, the top tab bar, and the active
/// tab's split layout.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let theme = appState.theme
        HStack(spacing: 0) {
            if appState.showSSHSidebar {
                SSHSidebarView()
                    .frame(width: 230)
                    .transition(.move(edge: .leading))
                Divider()
            }

            VStack(spacing: 0) {
                TabBarView()
                Divider().overlay(Color.black.opacity(0.4))
                content(theme: theme)
            }
        }
        .background(Color(theme.background).ignoresSafeArea())
        .background(WindowAccessor { window in
            window.setFrameAutosaveName("FalconMainWindow")
        })
        .animation(.easeInOut(duration: 0.18), value: appState.showSSHSidebar)
        .sheet(isPresented: $appState.showCommandPalette) {
            CommandPaletteView()
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func content(theme: Theme) -> some View {
        if let tab = appState.activeTab {
            SplitContainerView(tab: tab)
                .id(tab.id)
        } else {
            Color(theme.background)
        }
    }
}
