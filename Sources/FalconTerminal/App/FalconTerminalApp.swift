import SwiftUI

@main
struct FalconTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @State private var didBootstrap = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 640, minHeight: 400)
                .onAppear {
                    appDelegate.appState = appState
                    guard !didBootstrap else { return }
                    didBootstrap = true
                    if !appState.restoreSessionState() {
                        appState.newTab()
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            TerminalCommands(appState: appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 640, height: 480)
        }
    }
}
