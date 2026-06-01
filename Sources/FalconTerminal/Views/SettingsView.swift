import SwiftUI

/// The preferences window, organized into the product's required sections.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            TerminalSettings()
                .tabItem { Label("Terminal", systemImage: "terminal") }
            SSHSettings()
                .tabItem { Label("SSH", systemImage: "network") }
            ProfilesSettings()
                .tabItem { Label("Profiles", systemImage: "person.crop.rectangle.stack") }
            KeyboardSettings()
                .tabItem { Label("Keyboard", systemImage: "keyboard") }
            AIToolsSettings()
                .tabItem { Label("AI Tools", systemImage: "sparkles") }
        }
        .padding(20)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Form {
            Toggle("Restore tabs and panes on launch", isOn: $appState.settings.restoreSessionsOnLaunch)
            Toggle("Inline command suggestions", isOn: $appState.settings.inlineSuggestions)
            Toggle("Slash commands at the prompt (/new …)", isOn: $appState.settings.slashCommands)
            Toggle("Audible bell", isOn: $appState.settings.audibleBell)
            TextField("Default shell", text: $appState.settings.defaultShellPath)
        }
        .onChange(of: appState.settings) { _, _ in appState.persistSettings() }
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Form {
            Picker("Theme", selection: $appState.settings.themeName) {
                ForEach(Themes.all) { theme in Text(theme.name).tag(theme.name) }
            }
            Picker("Font", selection: $appState.settings.fontName) {
                ForEach(FontCatalog.available(), id: \.self) { Text($0).tag($0) }
            }
            HStack {
                Text("Font size")
                Slider(value: $appState.settings.fontSize, in: 9...28, step: 1)
                Text("\(Int(appState.settings.fontSize)) pt").monospacedDigit()
            }
            ThemePreview(theme: Themes.named(appState.settings.themeName))
                .frame(height: 90)
        }
        .onChange(of: appState.settings) { _, _ in appState.persistSettings() }
    }
}

private struct ThemePreview: View {
    let theme: Theme
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<16, id: \.self) { i in
                Rectangle().fill(Color(theme.palette[i]))
            }
        }
        .overlay(alignment: .leading) {
            Text(" Falcon ▸ ~ ")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(theme.foreground))
                .padding(6)
        }
        .background(Color(theme.background))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Terminal

private struct TerminalSettings: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Form {
            Picker("Cursor style", selection: $appState.settings.cursorStyle) {
                Text("Block").tag("block")
                Text("Bar").tag("bar")
                Text("Underline").tag("underline")
            }
            Stepper(
                "Scrollback: \(appState.settings.scrollbackLines) lines",
                value: $appState.settings.scrollbackLines,
                in: 1_000...1_000_000,
                step: 10_000
            )
        }
        .onChange(of: appState.settings) { _, _ in appState.persistSettings() }
    }
}

// MARK: - SSH

private struct SSHSettings: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SSHHost.ID?

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                List(selection: $selection) {
                    ForEach(appState.sshHosts) { host in
                        Text(host.name).tag(host.id)
                    }
                }
                HStack {
                    Button { addHost() } label: { Image(systemName: "plus") }
                    Button { removeSelected() } label: { Image(systemName: "minus") }
                        .disabled(selection == nil)
                    Spacer()
                }
            }
            .frame(width: 180)

            if let index = selectedIndex {
                hostEditor(index: index)
            } else {
                Text("Select a host").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: appState.sshHosts) { _, _ in appState.persistSSHHosts() }
    }

    private var selectedIndex: Int? {
        guard let selection else { return nil }
        return appState.sshHosts.firstIndex { $0.id == selection }
    }

    private func hostEditor(index: Int) -> some View {
        Form {
            TextField("Name", text: $appState.sshHosts[index].name)
            TextField("Hostname", text: $appState.sshHosts[index].hostname)
            TextField("Username", text: $appState.sshHosts[index].username)
            TextField("Port", value: $appState.sshHosts[index].port, format: .number)
            TextField("Identity file", text: $appState.sshHosts[index].identityFile)
            TextField("Group", text: $appState.sshHosts[index].group)
        }
    }

    private func addHost() {
        let host = SSHHost(name: "New Host", hostname: "example.com")
        appState.sshHosts.append(host)
        selection = host.id
    }

    private func removeSelected() {
        guard let selection else { return }
        appState.sshHosts.removeAll { $0.id == selection }
        self.selection = nil
    }
}

// MARK: - Profiles

private struct ProfilesSettings: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: Profile.ID?

    var body: some View {
        HStack(spacing: 12) {
            VStack {
                List(selection: $selection) {
                    ForEach(appState.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                HStack {
                    Button { addProfile() } label: { Image(systemName: "plus") }
                    Button { removeSelected() } label: { Image(systemName: "minus") }
                        .disabled(selection == nil)
                    Spacer()
                }
            }
            .frame(width: 180)

            if let index = selectedIndex {
                Form {
                    TextField("Name", text: $appState.profiles[index].name)
                    Picker("Theme", selection: $appState.profiles[index].themeName) {
                        ForEach(Themes.all) { Text($0.name).tag($0.name) }
                    }
                    TextField("Shell", text: $appState.profiles[index].shellPath)
                    TextField("Startup command", text: $appState.profiles[index].startupCommand)
                }
            } else {
                Text("Select a profile").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: appState.profiles) { _, _ in appState.persistProfiles() }
    }

    private var selectedIndex: Int? {
        guard let selection else { return nil }
        return appState.profiles.firstIndex { $0.id == selection }
    }

    private func addProfile() {
        let profile = Profile(name: "New Profile")
        appState.profiles.append(profile)
        selection = profile.id
    }

    private func removeSelected() {
        guard let selection else { return }
        appState.profiles.removeAll { $0.id == selection }
        self.selection = nil
    }
}

// MARK: - Keyboard

private struct KeyboardSettings: View {
    private let shortcuts: [(String, String)] = [
        ("⌘T", "New Tab"), ("⌘W", "Close Tab"), ("⌘⌥T", "Duplicate Tab"),
        ("⌘D", "Split Vertically"), ("⌘⇧D", "Split Horizontally"), ("⌘⇧W", "Close Pane"),
        ("⌘⌥→", "Next Tab"), ("⌘⌥←", "Previous Tab"),
        ("⌘C", "Copy"), ("⌘V", "Paste"), ("⌘A", "Select All"),
        ("⌘+", "Increase Font"), ("⌘-", "Decrease Font"), ("⌘⇧E", "Toggle SSH Sidebar")
    ]
    var body: some View {
        Table(shortcuts.map { Shortcut(keys: $0.0, action: $0.1) }) {
            TableColumn("Shortcut", value: \.keys)
            TableColumn("Action", value: \.action)
        }
    }
    private struct Shortcut: Identifiable {
        let id = UUID()
        let keys: String
        let action: String
    }
}

// MARK: - AI Tools

private struct AIToolsSettings: View {
    private let tools = ["claude", "gemini", "openai", "aider", "cursor", "codex"]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI CLI Tools")
                .font(.headline)
            Text("Falcon runs your shell with a full login environment, so any CLI on your PATH works without configuration. Detected tools:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            ForEach(tools, id: \.self) { tool in
                HStack {
                    Image(systemName: ToolDetection.isInstalled(tool) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(ToolDetection.isInstalled(tool) ? .green : .secondary)
                    Text(tool).font(.system(.body, design: .monospaced))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
