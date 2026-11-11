import AppKit
import ReaderCore

/// A document read as Markdown, rendered (the default) or as coloured source, or as plain
/// text; `--plain` only picks the starting mode. Small icons in the top-right corner switch
/// between them. In Markdown one icon toggles rendered and source, and a ¶ beside it, shown
/// only while the pointer is near the corner, reads the text as plain text. In plain text a
/// single icon reads it as rendered Markdown again. Each view is built the first time it is
/// shown and keeps its own scroll position.
final class MarkdownView: NSView, ReadingPane {
    private enum Kind { case rendered, source, plain }

    private let text: String
    private let directory: URL
    private var font: NSFont
    private var mode: TextMode
    private var showsSource = false
    private var panes: [Kind: ReadingPane] = [:]
    /// Switches between rendered and source; hidden in plain text.
    private let viewToggle: NSButton
    /// Switches between Markdown and plain text.
    private let modeToggle: NSButton
    private var cornerTracking: NSTrackingArea?
    /// Whether the pointer is near the corner, which shows `modeToggle` in Markdown.
    private var nearCorner = false

    private var kind: Kind { mode == .plain ? .plain : showsSource ? .source : .rendered }
    private var current: ReadingPane { pane(kind) }

    /// Relative links and images in the rendered view resolve against `directory`.
    init(frame: NSRect, text: String, mode: TextMode, font: NSFont, directory: URL) {
        self.text = text
        self.directory = directory
        self.font = font
        self.mode = mode
        viewToggle = Self.cornerButton()
        modeToggle = Self.cornerButton()
        super.init(frame: frame)
        wantsLayer = true
        for (button, action) in [
            (viewToggle, #selector(toggleView)), (modeToggle, #selector(toggleMode)),
        ] {
            button.target = self
            button.action = action
            addSubview(button)
        }
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    private static func cornerButton() -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = Typography.ink.withAlphaComponent(0.35)
        // Clicking it must leave keyboard focus on the text.
        button.refusesFirstResponder = true
        button.autoresizingMask = [.minXMargin, .minYMargin]
        return button
    }

    /// The view for `kind`, built and added the first time it is asked for.
    private func pane(_ kind: Kind) -> ReadingPane {
        if let pane = panes[kind] { return pane }
        let pane: ReadingPane
        switch kind {
        case .rendered:
            pane = RenderedView(frame: bounds, markdown: text, font: font, directory: directory)
        case .source: pane = ReaderView(frame: bounds, text: text, mode: .markdown, font: font)
        case .plain: pane = ReaderView(frame: bounds, text: text, mode: .plain, font: font)
        }
        pane.autoresizingMask = [.width, .height]
        addSubview(pane, positioned: .below, relativeTo: viewToggle)
        pane.scrollToTop()
        panes[kind] = pane
        return pane
    }

    @objc private func toggleView() {
        showsSource.toggle()
        update()
        window?.makeFirstResponder(current.focusView)
    }

    /// Markdown opens rendered, whichever view it showed before.
    @objc private func toggleMode() {
        mode = mode == .plain ? .markdown : .plain
        showsSource = false
        update()
        window?.makeFirstResponder(current.focusView)
    }

    /// Shows the current view and its icons; each icon names what a click switches to. The
    /// view toggle sits in the corner, with the ¶ to its left; plain text has only the
    /// Markdown icon, in the corner.
    private func update() {
        let shown = current
        for pane in panes.values { pane.isHidden = pane !== shown }
        let corner = NSRect(x: bounds.maxX - 52, y: bounds.maxY - 52, width: 28, height: 28)
        switch mode {
        case .plain:
            viewToggle.isHidden = true
            modeToggle.frame = corner
            Self.set(modeToggle, symbol: "doc.richtext", label: "Read as Markdown")
        case .markdown:
            viewToggle.isHidden = false
            viewToggle.frame = corner
            if showsSource {
                Self.set(viewToggle, symbol: "doc.richtext", label: "Show Rendered Markdown")
            } else {
                Self.set(
                    viewToggle, symbol: "chevron.left.forwardslash.chevron.right",
                    label: "Show Markdown Source")
            }
            modeToggle.frame = corner.offsetBy(dx: -30, dy: 0)
            Self.set(modeToggle, symbol: "paragraphsign", label: "Read as Plain Text")
        }
        revealModeToggle(animated: false)
    }

    private static func set(_ button: NSButton, symbol: String, label: String) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .light))
        button.toolTip = label
    }

    // MARK: Corner hover

    /// Where the pointer shows the ¶: the corner around both icons, so it appears as the
    /// pointer heads for the view toggle.
    private var cornerZone: NSRect {
        NSRect(x: bounds.maxX - 160, y: bounds.maxY - 110, width: 160, height: 110)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cornerTracking { removeTrackingArea(cornerTracking) }
        let tracking = NSTrackingArea(
            rect: cornerZone, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self)
        addTrackingArea(tracking)
        cornerTracking = tracking
        // A tracking area added under the pointer reports no entry until it moves.
        if let window {
            nearCorner = cornerZone.contains(
                convert(window.mouseLocationOutsideOfEventStream, from: nil))
            revealModeToggle(animated: false)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        nearCorner = true
        revealModeToggle(animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        nearCorner = false
        revealModeToggle(animated: true)
    }

    /// The ¶ stays clickable while transparent, but the pointer can only reach it through
    /// the corner zone, which shows it.
    private func revealModeToggle(animated: Bool) {
        let alpha: CGFloat = mode == .plain || nearCorner ? 1 : 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.15 : 0
            modeToggle.animator().alphaValue = alpha
        }
    }

    // MARK: ReadingPane

    var focusView: NSView { current.focusView }
    func scroll(_ command: ScrollCommand) { current.scroll(command) }
    func scrollToTop() {
        for pane in panes.values { pane.scrollToTop() }
    }
    func setFont(_ font: NSFont) {
        self.font = font
        for pane in panes.values { pane.setFont(font) }
    }
}
