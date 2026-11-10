import AppKit

/// Markdown shown two ways: rendered (the default) or as coloured source. A small icon in
/// the top-right corner switches between them; each view keeps its own scroll position.
final class MarkdownView: NSView, ReadingPane {
    private let rendered: RenderedView
    private let source: ReaderView
    private let toggle: NSButton
    private var showsSource = false

    private var current: ReadingPane { showsSource ? source : rendered }

    init(frame: NSRect, rendered: RenderedView, source: ReaderView) {
        self.rendered = rendered
        self.source = source
        toggle = NSButton(
            frame: NSRect(x: frame.width - 52, y: frame.height - 52, width: 28, height: 28))
        super.init(frame: frame)

        for pane in [rendered, source] as [NSView] {
            pane.frame = bounds
            pane.autoresizingMask = [.width, .height]
            addSubview(pane)
        }

        toggle.isBordered = false
        toggle.imagePosition = .imageOnly
        toggle.contentTintColor = Typography.ink.withAlphaComponent(0.35)
        // Clicking it must leave keyboard focus on the text.
        toggle.refusesFirstResponder = true
        toggle.autoresizingMask = [.minXMargin, .minYMargin]
        toggle.target = self
        toggle.action = #selector(toggleMode)
        addSubview(toggle)
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    @objc private func toggleMode() {
        showsSource.toggle()
        update()
        window?.makeFirstResponder(current.focusView)
    }

    /// Shows the current view; the icon names the view a click switches to.
    private func update() {
        rendered.isHidden = showsSource
        source.isHidden = !showsSource
        let (symbol, label) =
            showsSource
            ? ("doc.richtext", "Show Rendered Markdown")
            : ("chevron.left.forwardslash.chevron.right", "Show Markdown Source")
        toggle.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .light))
        toggle.toolTip = label
    }

    // MARK: ReadingPane

    var focusView: NSView { current.focusView }
    func scroll(_ command: ScrollCommand) { current.scroll(command) }
    func scrollToTop() {
        rendered.scrollToTop()
        source.scrollToTop()
    }
    func setFont(_ font: NSFont) {
        rendered.setFont(font)
        source.setFont(font)
    }
}
