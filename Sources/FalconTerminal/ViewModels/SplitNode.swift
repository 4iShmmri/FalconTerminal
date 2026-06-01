import Foundation

/// A node in a tab's binary split tree. A leaf carries a `PaneModel`; a branch
/// carries an axis, two children, and a divider ratio.
@MainActor
final class SplitNode: ObservableObject, Identifiable {
    let id = UUID()

    @Published var pane: PaneModel?
    @Published var axis: SplitAxis = .horizontal
    @Published var first: SplitNode?
    @Published var second: SplitNode?
    @Published var ratio: Double = 0.5

    init(pane: PaneModel) {
        self.pane = pane
    }

    init(axis: SplitAxis, ratio: Double, first: SplitNode, second: SplitNode) {
        self.pane = nil
        self.axis = axis
        self.ratio = ratio
        self.first = first
        self.second = second
    }

    var isLeaf: Bool { pane != nil }

    /// Split the leaf containing `paneID`, placing `newPane` on the trailing
    /// side. Returns true if the target leaf was found and split.
    func split(paneID: UUID, newPane: PaneModel, axis: SplitAxis) -> Bool {
        if let pane, pane.id == paneID {
            let existingLeaf = SplitNode(pane: pane)
            let newLeaf = SplitNode(pane: newPane)
            self.pane = nil
            self.axis = axis
            self.first = existingLeaf
            self.second = newLeaf
            self.ratio = 0.5
            return true
        }
        if first?.split(paneID: paneID, newPane: newPane, axis: axis) == true { return true }
        return second?.split(paneID: paneID, newPane: newPane, axis: axis) == true
    }

    /// All panes in reading order.
    func allPanes() -> [PaneModel] {
        if let pane { return [pane] }
        return (first?.allPanes() ?? []) + (second?.allPanes() ?? [])
    }

    var firstPaneID: UUID? { allPanes().first?.id }

    /// Returns the subtree with the pane removed, collapsing branches whose
    /// child disappears. Returns nil if this whole subtree should vanish.
    func removing(paneID: UUID) -> SplitNode? {
        if let pane { return pane.id == paneID ? nil : self }
        let newFirst = first?.removing(paneID: paneID)
        let newSecond = second?.removing(paneID: paneID)
        if newFirst == nil { return newSecond }
        if newSecond == nil { return newFirst }
        first = newFirst
        second = newSecond
        return self
    }
}
