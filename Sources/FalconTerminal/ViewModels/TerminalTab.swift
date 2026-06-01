import Foundation

/// A browser-style tab holding a split layout of terminal panes.
@MainActor
final class TerminalTab: ObservableObject, Identifiable {
    let id = UUID()

    /// A user-assigned name; when nil the active session's title is shown.
    @Published var customName: String?
    @Published var colorHex: String?
    @Published var pinned: Bool = false
    @Published var root: SplitNode
    @Published var activePaneID: UUID
    /// Mirrors the active pane's live title for display when unnamed.
    @Published var liveTitle: String = "Terminal"

    init(rootPane: PaneModel, customName: String? = nil) {
        self.root = SplitNode(pane: rootPane)
        self.activePaneID = rootPane.id
        self.customName = customName
        self.liveTitle = rootPane.session.title
    }

    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        return liveTitle.isEmpty ? "Terminal" : liveTitle
    }

    var panes: [PaneModel] { root.allPanes() }

    var activePane: PaneModel? {
        panes.first { $0.id == activePaneID } ?? panes.first
    }

    func split(newPane: PaneModel, axis: SplitAxis) {
        if root.split(paneID: activePaneID, newPane: newPane, axis: axis) {
            activePaneID = newPane.id
            objectWillChange.send()
        }
    }

    /// Close a pane. Returns true if the tab still has panes, false if the
    /// last pane closed (so the tab itself should close).
    @discardableResult
    func closePane(_ paneID: UUID) -> Bool {
        let pane = panes.first { $0.id == paneID }
        pane?.session.terminate()
        guard let newRoot = root.removing(paneID: paneID) else {
            return false
        }
        root = newRoot
        if activePaneID == paneID {
            activePaneID = newRoot.firstPaneID ?? paneID
        }
        objectWillChange.send()
        return true
    }

    func terminateAll() {
        for pane in panes { pane.session.terminate() }
    }
}
