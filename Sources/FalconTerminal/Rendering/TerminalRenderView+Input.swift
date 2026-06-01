import AppKit

/// Keyboard input, drag-selection, scrollback wheel handling, and clipboard
/// integration for the terminal surface.
extension TerminalRenderView {
    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        guard let session else { return }
        // Accept an inline suggestion before normal key handling.
        if handleSuggestionKey(event) { return }
        // Intercept `/command` typed at the prompt when Return is pressed.
        if (event.keyCode == 36 || event.keyCode == 76),
           !event.modifierFlags.contains(.command),
           interceptSlashCommandIfNeeded() {
            return
        }
        if let bytes = KeyEncoder.encode(event: event, applicationCursorKeys: session.applicationCursorKeys) {
            clearSelection()
            trackInput(event: event)
            session.send(bytes)
        } else {
            super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        onFocusChange?(true)
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        onFocusChange?(false)
        needsDisplay = true
        return super.resignFirstResponder()
    }

    // MARK: - Mouse selection

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let pos = gridPosition(for: event)
        setSelectionAnchor(pos)
        setSelectionEnd(pos)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        setSelectionEnd(gridPosition(for: event))
        autoscrollIfNeeded(for: event)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if selectionIsEmpty { clearSelection() }
        needsDisplay = true
    }

    private func gridPosition(for event: NSEvent) -> GridPos {
        let point = convert(event.locationInWindow, from: nil)
        let col = max(0, min(Int(point.x / metrics.cellWidth), maxColumns - 1))
        let row = max(0, min(Int(point.y / metrics.cellHeight), maxRows - 1))
        return GridPos(row: row, col: col)
    }

    private func autoscrollIfNeeded(for event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.y < 0 { session?.scrollBy(lines: 1) }
        else if point.y > bounds.height { session?.scrollBy(lines: -1) }
    }

    // MARK: - Scroll wheel

    override func scrollWheel(with event: NSEvent) {
        let lineDelta: Int
        if event.hasPreciseScrollingDeltas {
            lineDelta = Int((event.scrollingDeltaY / metrics.cellHeight).rounded())
        } else {
            lineDelta = Int(event.scrollingDeltaY.rounded())
        }
        if lineDelta != 0 { session?.scrollBy(lines: lineDelta) }
    }

    // MARK: - Clipboard

    @objc func copy(_ sender: Any?) {
        let text = selectedText()
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        session?.paste(text)
    }

    override func selectAll(_ sender: Any?) {
        setSelectionAnchor(GridPos(row: 0, col: 0))
        setSelectionEnd(GridPos(row: maxRows - 1, col: maxColumns - 1))
        needsDisplay = true
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)): return !selectionIsEmpty
        case #selector(paste(_:)): return NSPasteboard.general.string(forType: .string) != nil
        default: return true
        }
    }
}
