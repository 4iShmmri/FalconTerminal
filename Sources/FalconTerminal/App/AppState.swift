import SwiftUI
import Combine

/// The workspace controller: owns tabs, settings, profiles, and SSH hosts, and
/// exposes the actions the UI and menu commands invoke.
@MainActor
final class AppState: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var activeTabID: UUID?

    @Published var settings: AppSettings
    @Published var profiles: [Profile]
    @Published var sshHosts: [SSHHost]

    @Published var showSSHSidebar = false
    @Published var showCommandPalette = false

    private var titleObservers: [UUID: AnyCancellable] = [:]
    private var autosaveTask: Task<Void, Never>?

    init() {
        settings = Store.shared.load(AppSettings.self, from: Store.Files.settings) ?? .default
        profiles = Store.shared.load([Profile].self, from: Store.Files.profiles) ?? Profile.seeds
        sshHosts = Store.shared.load([SSHHost].self, from: Store.Files.sshHosts) ?? SSHHost.seeds
        startAutosave()
    }

    /// Periodically persist the workspace so a crash or force-quit still leaves
    /// a recent layout to restore from (the on-quit save is the other path).
    private func startAutosave() {
        autosaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !self.tabs.isEmpty else { continue }
                self.saveSessionState()
            }
        }
    }

    // MARK: - Derived appearance

    var theme: Theme { Themes.named(settings.themeName) }
    var fontName: String { settings.fontName }
    var fontSize: CGFloat { CGFloat(settings.fontSizeCG) }

    var activeTab: TerminalTab? {
        tabs.first { $0.id == activeTabID } ?? tabs.first
    }

    // MARK: - Session factory

    private func makeSession(workingDirectory: String? = nil, profile: Profile? = nil) -> TerminalSession {
        let session = TerminalSession()
        let shell = profile?.shellPath ?? settings.defaultShellPath
        let cwd = workingDirectory ?? FileManager.default.homeDirectoryForCurrentUser.path
        let config = SessionConfig.login(
            shell: shell,
            workingDirectory: cwd,
            environment: Shell.makeEnvironment()
        )
        session.start(config: config)
        if let command = profile?.startupCommand, !command.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                session.send(command + "\n")
            }
        }
        return session
    }

    private func makeSSHSession(for host: SSHHost) -> TerminalSession {
        let session = TerminalSession()
        let config = SessionConfig(
            executable: "/usr/bin/ssh",
            arguments: host.sshArguments,
            environment: Shell.makeEnvironment(),
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            columns: 80,
            rows: 24
        )
        session.start(config: config)
        return session
    }

    private func observeTitle(of pane: PaneModel, in tab: TerminalTab) {
        let paneID = pane.id
        titleObservers[paneID] = pane.session.$title
            .receive(on: RunLoop.main)
            .sink { [weak tab] title in
                guard let tab else { return }
                if tab.activePaneID == paneID { tab.liveTitle = title }
            }
    }

    // MARK: - Tab actions

    @discardableResult
    func newTab(profile: Profile? = nil, name: String? = nil) -> TerminalTab {
        let pane = PaneModel(session: makeSession(profile: profile))
        let tab = TerminalTab(rootPane: pane, customName: name)
        observeTitle(of: pane, in: tab)
        tabs.append(tab)
        activeTabID = tab.id
        return tab
    }

    func connect(to host: SSHHost) {
        let pane = PaneModel(session: makeSSHSession(for: host))
        let tab = TerminalTab(rootPane: pane, customName: host.name)
        observeTitle(of: pane, in: tab)
        tabs.append(tab)
        activeTabID = tab.id
    }

    func closeTab(_ tab: TerminalTab) {
        tab.terminateAll()
        for pane in tab.panes { titleObservers[pane.id] = nil }
        tabs.removeAll { $0.id == tab.id }
        if activeTabID == tab.id {
            activeTabID = tabs.last?.id
        }
        if tabs.isEmpty { newTab() }
    }

    func closeActiveTab() {
        if let tab = activeTab { closeTab(tab) }
    }

    func duplicateActiveTab() {
        guard let tab = activeTab else { return }
        newTab(name: tab.customName.map { "\($0) copy" })
    }

    func selectTab(_ tab: TerminalTab) { activeTabID = tab.id }

    func selectNextTab() { cycleTab(by: 1) }
    func selectPreviousTab() { cycleTab(by: -1) }

    private func cycleTab(by delta: Int) {
        guard let id = activeTabID, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let next = (idx + delta + tabs.count) % tabs.count
        activeTabID = tabs[next].id
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Split actions

    func splitActivePane(axis: SplitAxis) {
        guard let tab = activeTab else { return }
        let pane = PaneModel(session: makeSession())
        observeTitle(of: pane, in: tab)
        tab.split(newPane: pane, axis: axis)
    }

    func closeActivePane() {
        guard let tab = activeTab else { return }
        let paneID = tab.activePaneID
        titleObservers[paneID] = nil
        if tab.closePane(paneID) == false {
            closeTab(tab)
        }
    }

    // MARK: - Command palette

    /// Parse and run a slash command such as `/new aaa` or `new aaa`.
    func runCommand(_ raw: String) {
        var line = raw.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("/") { line.removeFirst() }
        guard !line.isEmpty else { return }

        let pieces = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let verb = pieces[0].lowercased()
        let argument = pieces.count > 1 ? pieces[1].trimmingCharacters(in: .whitespaces) : ""

        switch verb {
        case "new", "tab":
            newTab(name: argument.isEmpty ? nil : argument)
        case "rename", "name":
            if !argument.isEmpty { activeTab?.customName = argument }
        case "close", "closetab":
            closeActiveTab()
        case "duplicate", "dup":
            duplicateActiveTab()
        case "split", "vsplit", "v":
            splitActivePane(axis: .horizontal)
        case "hsplit", "h":
            splitActivePane(axis: .vertical)
        case "closepane", "killpane":
            closeActivePane()
        case "ssh", "connect":
            connectToHost(named: argument)
        case "theme":
            if let theme = matchTheme(argument) { applyTheme(named: theme.name) }
        case "font", "fontsize":
            if let size = Double(argument) { settings.fontSize = max(8, min(size, 48)); persistSettings() }
        case "clear", "cls":
            activeTab?.activePane?.session.send("clear\n")
        case "sidebar", "ssh-sidebar":
            showSSHSidebar.toggle()
        default:
            break
        }
    }

    private func connectToHost(named query: String) {
        guard !query.isEmpty else {
            showSSHSidebar = true
            return
        }
        let lower = query.lowercased()
        let match = sshHosts.first { $0.name.lowercased() == lower }
            ?? sshHosts.first { $0.name.lowercased().contains(lower) || $0.hostname.lowercased().contains(lower) }
        if let match { connect(to: match) }
    }

    private func matchTheme(_ query: String) -> Theme? {
        guard !query.isEmpty else { return nil }
        let lower = query.lowercased()
        return Themes.all.first { $0.name.lowercased() == lower }
            ?? Themes.all.first { $0.name.lowercased().contains(lower) }
    }

    // MARK: - Appearance actions

    func applyTheme(named name: String) {
        settings.themeName = name
        persistSettings()
    }

    func adjustFontSize(by delta: Double) {
        settings.fontSize = max(8, min(settings.fontSize + delta, 48))
        persistSettings()
    }

    // MARK: - Restoration helpers (used by SessionRestoration)

    func makeRestoredPane(workingDirectory: String? = nil) -> PaneModel {
        let dir = (workingDirectory.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil })
        return PaneModel(session: makeSession(workingDirectory: dir))
    }

    func registerRestoredPane(_ pane: PaneModel, in tab: TerminalTab) {
        observeTitle(of: pane, in: tab)
    }

    // MARK: - Persistence

    func persistSettings() { Store.shared.save(settings, to: Store.Files.settings) }
    func persistProfiles() { Store.shared.save(profiles, to: Store.Files.profiles) }
    func persistSSHHosts() { Store.shared.save(sshHosts, to: Store.Files.sshHosts) }
}
