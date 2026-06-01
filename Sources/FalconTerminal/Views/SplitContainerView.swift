import SwiftUI

/// Renders a tab's split tree, observing it so layout changes (split/close)
/// refresh the view.
struct SplitContainerView: View {
    @ObservedObject var tab: TerminalTab

    var body: some View {
        SplitNodeView(node: tab.root, tab: tab)
            .padding(1)
    }
}

/// Recursive renderer for a single split node.
struct SplitNodeView: View {
    @ObservedObject var node: SplitNode
    @ObservedObject var tab: TerminalTab

    private let dividerThickness: CGFloat = 6

    var body: some View {
        if let pane = node.pane {
            TerminalPaneView(pane: pane, tab: tab)
        } else if let first = node.first, let second = node.second {
            branch(first: first, second: second)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func branch(first: SplitNode, second: SplitNode) -> some View {
        GeometryReader { geo in
            let isHorizontal = node.axis == .horizontal
            let total = isHorizontal ? geo.size.width : geo.size.height
            let available = max(0, total - dividerThickness)
            let firstSize = available * node.ratio
            let secondSize = available - firstSize

            Group {
                if isHorizontal {
                    HStack(spacing: 0) {
                        SplitNodeView(node: first, tab: tab).frame(width: firstSize)
                        divider(isHorizontal: true, total: total)
                        SplitNodeView(node: second, tab: tab).frame(width: secondSize)
                    }
                } else {
                    VStack(spacing: 0) {
                        SplitNodeView(node: first, tab: tab).frame(height: firstSize)
                        divider(isHorizontal: false, total: total)
                        SplitNodeView(node: second, tab: tab).frame(height: secondSize)
                    }
                }
            }
            .coordinateSpace(name: "split")
        }
    }

    private func divider(isHorizontal: Bool, total: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.6))
            .frame(
                width: isHorizontal ? dividerThickness : nil,
                height: isHorizontal ? nil : dividerThickness
            )
            .overlay(
                Rectangle().fill(Color.white.opacity(0.06))
                    .frame(
                        width: isHorizontal ? 1 : nil,
                        height: isHorizontal ? nil : 1
                    )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .named("split"))
                    .onChanged { value in
                        guard total > 0 else { return }
                        let pos = isHorizontal ? value.location.x : value.location.y
                        node.ratio = min(0.9, max(0.1, pos / total))
                    }
            )
            .onHover { hovering in
                if hovering {
                    (isHorizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
