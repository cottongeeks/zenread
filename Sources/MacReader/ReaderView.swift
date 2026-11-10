import AppKit
import ReaderCore

/// A reading-oriented scroll key.
enum ScrollCommand {
    case pageDown, pageUp, lineDown, lineUp, top, bottom

    /// How much of the visible height a page step moves.
    static let pageFraction: CGFloat = 0.85

    /// The command `event` asks for, or nil when it is not a scroll key.
    init?(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""
        switch (event.keyCode, chars) {
        case (49, _):  // space
            self = flags.contains(.shift) ? .pageUp : .pageDown
        case (121, _), (_, "f"), (_, "d"):  // page down, f, d
            self = .pageDown
        case (116, _), (_, "b"), (_, "u"):  // page up, b, u
            self = .pageUp
        case (125, _), (_, "j"):  // down arrow, j
            self = flags.contains(.command) ? .bottom : .lineDown
        case (126, _), (_, "k"):  // up arrow, k
            self = flags.contains(.command) ? .top : .lineUp
        case (115, _), (_, "g"):  // home, g
            self = .top
        case (119, _), (_, "G"):  // end, G
            self = .bottom
        default:
            return nil
        }
    }
}

/// A view that shows the document and scrolls it from the keyboard.
@MainActor
protocol ReadingPane: NSView {
    /// The view to make first responder, so copy and select all reach the text.
    var focusView: NSView { get }
    func scroll(_ command: ScrollCommand)
    /// Scrolls to the start of the document without animation.
    func scrollToTop()
    /// Sets the body text in `font`, scaling the column with it and keeping the reading
    /// position.
    func setFont(_ font: NSFont)
}

/// Read-only text view that never scrolls itself to the (invisible) caret.
/// AppKit does that when a text view becomes first responder, which would
/// hide the top inset on launch; all scrolling here is driven by the user.
final class ReaderTextView: NSTextView {
    override func scrollRangeToVisible(_ range: NSRange) {}
}

/// A scroll view containing a single read-only text column centred on screen.
/// Owns the thin overlay scroller and all keyboard scrolling behaviour.
final class ReaderView: NSScrollView, ReadingPane {
    let textView: ReaderTextView
    private let text: String
    private let mode: TextMode
    /// One-line scroll step: the body line height. Taken from the body font, not
    /// `textView.font`, which reports the first character's font (a heading or code block
    /// in Markdown).
    private var lineStep: CGFloat
    /// Column width for the body font.
    private var measure: CGFloat

    /// Shows `text` styled by `Typography.document` for `mode` in `font`.
    init(frame: NSRect, text: String, mode: TextMode, font: NSFont) {
        self.text = text
        self.mode = mode
        lineStep = font.pointSize * Typography.leading
        measure = Typography.measure(size: font.pointSize)
        let container = NSTextContainer(
            size: NSSize(width: measure, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        let storage = NSTextStorage(
            attributedString: Typography.document(text, mode: mode, font: font))
        storage.addLayoutManager(layoutManager)

        textView = ReaderTextView(frame: frame, textContainer: container)
        super.init(frame: frame)

        configureTextView()
        configureScrollView()
        documentView = textView
        layoutColumn()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    private func configureTextView() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.usesFontPanel = false
        textView.allowsUndo = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        // A reader has nothing to rewrite, so no Writing Tools or Summarize in the context
        // menu. (A read-only text view shows no Writing Tools button on selected text anyway.)
        if #available(macOS 15.0, *) { textView.writingToolsBehavior = .none }
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.18)
        ]
        textView.insertionPointColor = .clear
        textView.layoutManager?.usesFontLeading = false
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    /// Scrolls to the start of the document without animation.
    func scrollToTop() {
        contentView.scroll(to: .zero)
        reflectScrolledClipView(contentView)
    }

    private func configureScrollView() {
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        // Overlay scrollers are the thin, fade-away kind; the light knob
        // style is the one meant for dark content.
        scrollerStyle = .overlay
        scrollerKnobStyle = .light
        verticalScrollElasticity = .allowed
        horizontalScrollElasticity = .none
        borderType = .noBorder
        autoresizingMask = [.width, .height]
    }

    /// Centres the measure-wide text container inside the view by padding the
    /// text view's inset. Vertical inset gives the first line some breathing
    /// room from the top of the screen.
    private func layoutColumn() {
        let width = bounds.width
        let column = min(measure, width - 2 * Typography.margin)
        textView.textContainer?.containerSize = NSSize(
            width: column, height: CGFloat.greatestFiniteMagnitude)
        let sideInset = max(Typography.margin, (width - column) / 2)
        let topInset = (bounds.height * 0.12).rounded()
        textView.textContainerInset = NSSize(width: sideInset, height: topInset)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutColumn()
    }

    func setFont(_ font: NSFont) {
        // The same fraction of the document stays at the top of the screen.
        let fraction = contentView.bounds.minY / max(1, textView.frame.height)
        lineStep = font.pointSize * Typography.leading
        measure = Typography.measure(size: font.pointSize)
        textView.textStorage?.setAttributedString(
            Typography.document(text, mode: mode, font: font))
        layoutColumn()
        if let layoutManager = textView.layoutManager, let container = textView.textContainer {
            layoutManager.ensureLayout(for: container)
        }
        textView.sizeToFit()
        let maxY = max(0, textView.frame.height - contentView.bounds.height)
        contentView.scroll(
            to: NSPoint(x: 0, y: min(maxY, (fraction * textView.frame.height).rounded())))
        reflectScrolledClipView(contentView)
    }

    // MARK: Keyboard scrolling

    var focusView: NSView { textView }

    func scroll(_ command: ScrollCommand) {
        let clip = contentView
        let visible = clip.bounds
        let maxY = max(0, textView.frame.height - visible.height)
        let page = visible.height * ScrollCommand.pageFraction

        let y: CGFloat
        switch command {
        case .pageDown: y = visible.minY + page
        case .pageUp: y = visible.minY - page
        case .lineDown: y = visible.minY + lineStep
        case .lineUp: y = visible.minY - lineStep
        case .top: y = 0
        case .bottom: y = maxY
        }
        let target = NSPoint(x: 0, y: min(max(0, y), maxY))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            clip.animator().setBoundsOrigin(target)
            reflectScrolledClipView(clip)
        }
        flashScrollers()
    }
}
