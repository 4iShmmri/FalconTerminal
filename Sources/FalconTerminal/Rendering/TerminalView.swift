import SwiftUI
import AppKit

/// Bridges the AppKit `TerminalRenderView` into SwiftUI, wiring the session's
/// snapshot/bell callbacks and propagating theme/font changes.
struct TerminalView: NSViewRepresentable {
    let session: TerminalSession
    let theme: Theme
    let fontName: String
    let fontSize: CGFloat
    var inlineSuggestions: Bool = true
    var slashCommands: Bool = true
    var focusOnAppear: Bool = true
    var onFocus: (() -> Void)? = nil
    var onSlashCommand: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> TerminalRenderView {
        let view = TerminalRenderView(theme: theme, fontName: fontName, fontSize: fontSize)
        view.session = session
        view.autosuggestEnabled = inlineSuggestions
        view.slashCommandsEnabled = slashCommands
        view.onSlashCommand = onSlashCommand
        context.coordinator.view = view

        session.onSnapshot = { [weak view] snapshot in
            view?.apply(snapshot)
        }
        session.onBell = {
            NSSound.beep()
        }
        let coordinator = context.coordinator
        view.onFocusChange = { focused in
            if focused { coordinator.onFocus?() }
        }
        coordinator.onFocus = onFocus
        session.requestRender()

        if focusOnAppear {
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        }
        return view
    }

    func updateNSView(_ view: TerminalRenderView, context: Context) {
        context.coordinator.onFocus = onFocus
        view.autosuggestEnabled = inlineSuggestions
        view.slashCommandsEnabled = slashCommands
        view.onSlashCommand = onSlashCommand
        if view.theme != theme { view.update(theme: theme) }
        if context.coordinator.fontName != fontName || context.coordinator.fontSize != fontSize {
            context.coordinator.fontName = fontName
            context.coordinator.fontSize = fontSize
            view.update(fontName: fontName, fontSize: fontSize)
        }
    }

    @MainActor
    final class Coordinator {
        weak var view: TerminalRenderView?
        var fontName: String = ""
        var fontSize: CGFloat = 0
        var onFocus: (() -> Void)?
    }
}
