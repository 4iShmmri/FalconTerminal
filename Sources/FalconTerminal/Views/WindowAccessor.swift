import SwiftUI
import AppKit

/// Bridges to the hosting `NSWindow` so we can enable frame autosave (which
/// persists and restores the window's position and size across launches).
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window { onWindow(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
