import AppKit

struct GridPos: Equatable {
    var row: Int
    var col: Int
}

/// The core terminal surface: an `NSView` that renders a `TerminalSnapshot`
/// on a fixed character grid with CoreText, routes keyboard input to the
/// session, and supports drag-selection + copy/paste and scrollback.
final class TerminalRenderView: NSView, NSUserInterfaceValidations {
    weak var session: TerminalSession?

    private(set) var theme: Theme
    private(set) var metrics: FontMetrics
    var snapshot = TerminalSnapshot.empty
    var selectionAnchor: GridPos?
    var selectionEnd: GridPos?

    private var colorCache: [RGBColor: NSColor] = [:]
    private var lastReportedCols = 0
    private var lastReportedRows = 0

    var onFocusChange: ((Bool) -> Void)?

    // Inline autosuggestion state (fish-style ghost text from history).
    var autosuggestEnabled = true
    var trackedLine = ""
    var lineDirty = false
    var suggestionSuffix = ""

    // Slash-command interception (`/new` at the prompt → app action).
    var slashCommandsEnabled = true
    var onSlashCommand: ((String) -> Void)?

    init(theme: Theme, fontName: String, fontSize: CGFloat) {
        self.theme = theme
        self.metrics = FontMetrics(fontName: fontName, size: fontSize)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = theme.background.nsColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    // MARK: - External updates

    func apply(_ snapshot: TerminalSnapshot) {
        self.snapshot = snapshot
        needsDisplay = true
    }

    func update(theme: Theme) {
        self.theme = theme
        colorCache.removeAll()
        layer?.backgroundColor = theme.background.nsColor.cgColor
        needsDisplay = true
    }

    func update(fontName: String, fontSize: CGFloat) {
        metrics = FontMetrics(fontName: fontName, size: fontSize)
        recomputeGridSize(force: true)
        needsDisplay = true
    }

    // MARK: - Layout / grid sizing

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        recomputeGridSize(force: false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        recomputeGridSize(force: true)
    }

    private func recomputeGridSize(force: Bool) {
        let cols = max(1, Int(bounds.width / metrics.cellWidth))
        let rows = max(1, Int(bounds.height / metrics.cellHeight))
        guard force || cols != lastReportedCols || rows != lastReportedRows else { return }
        lastReportedCols = cols
        lastReportedRows = rows
        session?.resize(columns: cols, rows: rows)
        session?.requestRender()
    }

    // MARK: - Colors

    private func nsColor(_ c: RGBColor) -> NSColor {
        if let cached = colorCache[c] { return cached }
        let color = c.nsColor
        colorCache[c] = color
        return color
    }

    private func foregroundColor(for cell: Cell) -> RGBColor {
        let bold = cell.attributes.contains(.bold)
        if cell.attributes.contains(.inverse) {
            return theme.resolve(cell.background, isForeground: false)
        }
        return theme.resolve(cell.foreground, isForeground: true, bold: bold)
    }

    private func backgroundColor(for cell: Cell) -> RGBColor {
        if cell.attributes.contains(.inverse) {
            return theme.resolve(cell.foreground, isForeground: true)
        }
        return theme.resolve(cell.background, isForeground: false)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cw = metrics.cellWidth
        let ch = metrics.cellHeight

        // Base background.
        let baseBG = snapshot.reverseVideo ? theme.foreground : theme.background
        nsColor(baseBG).setFill()
        ctx.fill(bounds)

        guard !snapshot.lines.isEmpty else { return }
        let cols = snapshot.columns
        let normSel = normalizedSelection()

        for row in 0..<snapshot.rows where row < snapshot.lines.count {
            let line = snapshot.lines[row]
            let y = CGFloat(row) * ch

            drawBackgrounds(line: line, row: row, y: y, cols: cols, cw: cw, ch: ch, selection: normSel)
            drawGlyphs(line: line, y: y, cols: cols, cw: cw)
        }

        drawSuggestion(cw: cw, ch: ch)
        drawCursor(cw: cw, ch: ch)
    }

    /// Dim ghost text continuing the current command from history.
    private func drawSuggestion(cw: CGFloat, ch: CGFloat) {
        guard autosuggestEnabled, !suggestionSuffix.isEmpty,
              !snapshot.altScreen, snapshot.atBottom, snapshot.cursorVisible else { return }
        let y = CGFloat(snapshot.cursorRow) * ch + metrics.baselineOffset
        let attrs: [NSAttributedString.Key: Any] = [
            .font: metrics.font,
            .foregroundColor: nsColor(theme.foreground).withAlphaComponent(0.36)
        ]
        var col = snapshot.cursorColumn
        for character in suggestionSuffix {
            if col >= snapshot.columns { break }
            (String(character) as NSString).draw(
                at: CGPoint(x: CGFloat(col) * cw, y: y),
                withAttributes: attrs
            )
            col += 1
        }
    }

    private func drawBackgrounds(
        line: TerminalLine, row: Int, y: CGFloat, cols: Int,
        cw: CGFloat, ch: CGFloat, selection: (start: GridPos, end: GridPos)?
    ) {
        var col = 0
        while col < cols {
            guard col < line.cells.count else { break }
            let selected = isSelected(row: row, col: col, selection: selection)
            let bg = backgroundColor(for: line.cells[col])
            let isDefault = !selected && bg == theme.background && !snapshot.reverseVideo

            if isDefault { col += 1; continue }

            // Extend a run of identical fill.
            var runEnd = col + 1
            while runEnd < cols, runEnd < line.cells.count,
                  isSelected(row: row, col: runEnd, selection: selection) == selected,
                  backgroundColor(for: line.cells[runEnd]) == bg {
                runEnd += 1
            }
            let fill = selected ? theme.selection : bg
            nsColor(fill).setFill()
            let rect = NSRect(x: CGFloat(col) * cw, y: y, width: CGFloat(runEnd - col) * cw, height: ch)
            rect.fill()
            col = runEnd
        }
    }

    private func drawGlyphs(line: TerminalLine, y: CGFloat, cols: Int, cw: CGFloat) {
        let top = y + metrics.baselineOffset

        // Lines containing Arabic / Hebrew need contextual shaping (joining) and
        // bidi reordering, which per-cell drawing destroys. Render the whole
        // line as one CoreText run so glyphs join and lay out right-to-left.
        if lineNeedsComplexLayout(line, cols: cols) {
            drawComplexLine(line: line, top: top, cols: cols, width: CGFloat(cols) * cw)
            return
        }

        for col in 0..<cols where col < line.cells.count {
            let cell = line.cells[col]
            if cell.attributes.contains(.wideTrailer) { continue }
            if cell.attributes.contains(.invisible) { continue }
            let s = cell.string
            if s == " " { continue }
            let attrs = attributes(for: cell)
            (s as NSString).draw(at: CGPoint(x: CGFloat(col) * cw, y: top), withAttributes: attrs)
        }
    }

    private func lineNeedsComplexLayout(_ line: TerminalLine, cols: Int) -> Bool {
        for col in 0..<min(cols, line.cells.count) {
            for scalar in line.cells[col].scalars where Self.isComplexScript(scalar) {
                return true
            }
        }
        return false
    }

    private static func isComplexScript(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x05FF,   // Hebrew
             0x0600...0x06FF,   // Arabic
             0x0750...0x077F,   // Arabic Supplement
             0x08A0...0x08FF,   // Arabic Extended-A
             0xFB1D...0xFDFF,   // Hebrew & Arabic presentation forms-A
             0xFE70...0xFEFF:   // Arabic presentation forms-B
            return true
        default:
            return false
        }
    }

    /// Draw an entire line as one attributed string. CoreText performs Arabic
    /// joining and the Unicode bidi algorithm, and substitutes an Arabic-capable
    /// font for glyphs the base monospace font lacks.
    private func drawComplexLine(line: TerminalLine, top: CGFloat, cols: Int, width: CGFloat) {
        let attributed = NSMutableAttributedString()
        for col in 0..<min(cols, line.cells.count) {
            let cell = line.cells[col]
            if cell.attributes.contains(.wideTrailer) { continue }
            let text = cell.attributes.contains(.invisible) ? " " : cell.string
            attributed.append(NSAttributedString(string: text, attributes: attributes(for: cell)))
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .natural   // first strong char decides direction
        paragraph.lineBreakMode = .byClipping
        paragraph.alignment = .natural
        attributed.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: attributed.length)
        )

        attributed.draw(with: NSRect(x: 0, y: top, width: width, height: metrics.cellHeight),
                        options: [.usesLineFragmentOrigin])
    }

    private func attributes(for cell: Cell) -> [NSAttributedString.Key: Any] {
        let bold = cell.attributes.contains(.bold)
        let italic = cell.attributes.contains(.italic)
        var fg = foregroundColor(for: cell)
        if cell.attributes.contains(.faint) {
            fg = RGBColor(fg.r / 2, fg.g / 2, fg.b / 2)
        }
        var attrs: [NSAttributedString.Key: Any] = [
            .font: metrics.font(bold: bold, italic: italic),
            .foregroundColor: nsColor(fg)
        ]
        if cell.attributes.contains(.underline) {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if cell.attributes.contains(.strikethrough) {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    private func drawCursor(cw: CGFloat, ch: CGFloat) {
        guard snapshot.cursorVisible else { return }
        let row = snapshot.cursorRow
        let col = snapshot.cursorColumn
        guard row >= 0, row < snapshot.rows, col >= 0, col < snapshot.columns else { return }
        let x = CGFloat(col) * cw
        let y = CGFloat(row) * ch
        let focused = window?.firstResponder === self
        let cursorColor = nsColor(theme.cursor)
        cursorColor.setFill()

        let cellComplex = row < snapshot.lines.count && col < snapshot.lines[row].cells.count
            && snapshot.lines[row].cells[col].scalars.contains { Self.isComplexScript($0) }

        switch snapshot.cursorStyle {
        case .block:
            let rect = NSRect(x: x, y: y, width: cw, height: ch)
            if focused && !cellComplex {
                rect.fill()
                redrawGlyphUnderCursor(row: row, col: col, x: x, y: y)
            } else {
                let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
                path.lineWidth = 1
                path.stroke()
            }
        case .bar:
            NSRect(x: x, y: y, width: 2, height: ch).fill()
        case .underline:
            NSRect(x: x, y: y + ch - 2, width: cw, height: 2).fill()
        }
    }

    private func redrawGlyphUnderCursor(row: Int, col: Int, x: CGFloat, y: CGFloat) {
        guard row < snapshot.lines.count, col < snapshot.lines[row].cells.count else { return }
        let cell = snapshot.lines[row].cells[col]
        let s = cell.string
        guard s != " " else { return }
        let bold = cell.attributes.contains(.bold)
        let italic = cell.attributes.contains(.italic)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: metrics.font(bold: bold, italic: italic),
            .foregroundColor: nsColor(theme.cursorText)
        ]
        (s as NSString).draw(at: CGPoint(x: x, y: y + metrics.baselineOffset), withAttributes: attrs)
    }
}
