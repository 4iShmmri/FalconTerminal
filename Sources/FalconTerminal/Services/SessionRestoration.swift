import Foundation

/// Serializable snapshot of the workspace layout (tab names, colors, pin
/// state, and split structure). Sessions are relaunched fresh on restore — the
/// shape of the workspace is preserved, not live process state.
struct RestorableState: Codable, Sendable {
    var tabs: [RestorableTab]
    var activeIndex: Int
}

struct RestorableTab: Codable, Sendable {
    var customName: String?
    var colorHex: String?
    var pinned: Bool
    var layout: RestorableNode
}

indirect enum RestorableNode: Codable, Sendable {
    case leaf(cwd: String?)
    case branch(axis: SplitAxis, ratio: Double, first: RestorableNode, second: RestorableNode)
}

@MainActor
extension AppState {
    /// Capture the current layout to disk.
    func saveSessionState() {
        let restorableTabs = tabs.map { tab in
            RestorableTab(
                customName: tab.customName,
                colorHex: tab.colorHex,
                pinned: tab.pinned,
                layout: Self.encode(node: tab.root)
            )
        }
        let activeIndex = tabs.firstIndex { $0.id == activeTabID } ?? 0
        let state = RestorableState(tabs: restorableTabs, activeIndex: max(0, activeIndex))
        Store.shared.save(state, to: Store.Files.session)
    }

    private static func encode(node: SplitNode) -> RestorableNode {
        if node.isLeaf { return .leaf(cwd: node.pane?.session.currentDirectory()) }
        guard let first = node.first, let second = node.second else { return .leaf(cwd: nil) }
        return .branch(
            axis: node.axis,
            ratio: node.ratio,
            first: encode(node: first),
            second: encode(node: second)
        )
    }

    /// Rebuild the workspace from disk. Returns true if anything was restored.
    @discardableResult
    func restoreSessionState() -> Bool {
        guard settings.restoreSessionsOnLaunch,
              let state = Store.shared.load(RestorableState.self, from: Store.Files.session),
              !state.tabs.isEmpty else {
            return false
        }

        for restorable in state.tabs {
            let root = buildNode(restorable.layout)
            guard let firstPane = root.allPanes().first else { continue }
            let tab = TerminalTab(rootPane: firstPane, customName: restorable.customName)
            tab.root = root
            tab.activePaneID = firstPane.id
            tab.colorHex = restorable.colorHex
            tab.pinned = restorable.pinned
            for pane in root.allPanes() { registerRestoredPane(pane, in: tab) }
            tabs.append(tab)
        }

        if tabs.isEmpty { return false }
        let idx = min(state.activeIndex, tabs.count - 1)
        activeTabID = tabs[idx].id
        return true
    }

    private func buildNode(_ node: RestorableNode) -> SplitNode {
        switch node {
        case let .leaf(cwd):
            return SplitNode(pane: makeRestoredPane(workingDirectory: cwd))
        case let .branch(axis, ratio, first, second):
            return SplitNode(
                axis: axis,
                ratio: ratio,
                first: buildNode(first),
                second: buildNode(second)
            )
        }
    }
}
