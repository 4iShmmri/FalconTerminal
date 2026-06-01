import Foundation

/// A single terminal pane inside a tab's split layout.
@MainActor
final class PaneModel: ObservableObject, Identifiable {
    let id = UUID()
    let session: TerminalSession

    init(session: TerminalSession) {
        self.session = session
    }
}

/// Orientation of a split branch.
enum SplitAxis: String, Codable, Sendable {
    /// Children laid out left → right (a vertical divider). `⌘D`.
    case horizontal
    /// Children laid out top → bottom (a horizontal divider). `⌘⇧D`.
    case vertical
}
