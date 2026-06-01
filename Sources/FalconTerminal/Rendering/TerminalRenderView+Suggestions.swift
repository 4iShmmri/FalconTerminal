import AppKit

/// Heuristic current-line tracking that drives fish-style inline suggestions.
///
/// We can't read the shell's line editor, so we reconstruct the typed line from
/// keystrokes: printable keys append, Backspace removes, Return records the
/// command to history and resets. Anything ambiguous (arrows, Ctrl-keys, Tab,
/// history recall, alternate-screen apps) marks the line "dirty" and hides the
/// suggestion until the next clean prompt — so we never show a wrong guess.
extension TerminalRenderView {
    /// Returns true if the event was consumed as a suggestion-accept.
    func handleSuggestionKey(_ event: NSEvent) -> Bool {
        guard autosuggestEnabled, !suggestionSuffix.isEmpty, !lineDirty,
              !snapshot.altScreen,
              !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.control) else { return false }
        // Right arrow or Ctrl-E style "accept" → type the rest of the command.
        if event.keyCode == 124 { // Right arrow
            let suffix = suggestionSuffix
            trackedLine += suffix
            suggestionSuffix = ""
            session?.send(suffix)
            needsDisplay = true
            return true
        }
        return false
    }

    /// Update the tracked line from a key event, then refresh the suggestion.
    func trackInput(event: NSEvent) {
        if snapshot.altScreen {
            resetLineTracking()
            return
        }

        let flags = event.modifierFlags
        if flags.contains(.command) { return } // app shortcut, ignore
        if flags.contains(.control) || flags.contains(.option) {
            resetLineTracking()   // Ctrl/Meta editing — stop guessing this line
            return
        }

        switch event.keyCode {
        case 36, 76:              // Return / keypad Enter
            CommandHistory.shared.record(trackedLine)
            resetLineTracking()
            return
        case 51:                  // Backspace
            if !lineDirty, !trackedLine.isEmpty { trackedLine.removeLast() }
        case 123, 124, 125, 126,  // arrows
             48, 53,              // Tab, Esc
             115, 116, 117, 119, 121: // Home/End/Fwd-del/PgUp/PgDn
            lineDirty = true
        default:
            if !lineDirty, let text = event.charactersIgnoringModifiers,
               text.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol || $0 == " " }) {
                trackedLine += text
            } else {
                lineDirty = true
            }
        }

        refreshSuggestion()
    }

    private func refreshSuggestion() {
        guard autosuggestEnabled, !lineDirty, !trackedLine.isEmpty else {
            if !suggestionSuffix.isEmpty { suggestionSuffix = ""; needsDisplay = true }
            return
        }
        let suffix = CommandHistory.shared.suggestionSuffix(for: trackedLine) ?? ""
        if suffix != suggestionSuffix {
            suggestionSuffix = suffix
            needsDisplay = true
        }
    }

    /// If the user pressed Return on a `/command` line we recognise, clear the
    /// shell's input line, run the app command, and swallow the Return. Returns
    /// true when the command was intercepted.
    func interceptSlashCommandIfNeeded() -> Bool {
        guard slashCommandsEnabled, !lineDirty, !snapshot.altScreen else { return false }
        let line = trackedLine.trimmingCharacters(in: .whitespaces)
        guard Self.isInterceptableSlashCommand(line) else { return false }

        // Erase what the user typed at the prompt (Ctrl-U kills the line), then
        // run the app command and reset our tracking.
        session?.send("\u{15}")
        onSlashCommand?(line)
        resetLineTracking()
        return true
    }

    private static func isInterceptableSlashCommand(_ line: String) -> Bool {
        guard line.hasPrefix("/") else { return false }
        let body = line.dropFirst()
        let token = String(body.split(separator: " ").first ?? "")
        guard !token.isEmpty, !token.contains("/") else { return false }
        let t = token.lowercased()
        return PaletteCommand.all.contains { $0.name == t || $0.aliases.contains(t) }
    }

    private func resetLineTracking() {
        trackedLine = ""
        lineDirty = false
        if !suggestionSuffix.isEmpty { needsDisplay = true }
        suggestionSuffix = ""
    }
}
