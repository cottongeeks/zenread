import AppKit
import ReaderCore

/// Wires the window, menus and the global key handling together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The loaded file, unmodified; `Typography.document` applies the mode.
    private let text: String
    private let options: Options
    private var window: ReaderWindow?
    private var pane: ReadingPane?
    /// The body font at the current zoom.
    private var font: NSFont?
    /// Sizes ⌘+ and ⌘- move between; the largest still fits the column on the screen.
    private var sizes: ClosedRange<CGFloat> = Typography.minimumSize...Typography.defaultSize

    init(text: String, options: Options) {
        self.text = text
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        // Hide the menu bar and Dock while we are frontmost; they come back
        // when the pointer hits the screen edge, which is standard macOS
        // full-screen behaviour.
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        let screen = Self.targetScreen()
        let spaceMode = SpaceMode.forScreen(screen)
        let window = ReaderWindow(screen: screen, spaceMode: spaceMode)
        let font = Typography.bodyFont(name: options.fontName, size: Typography.defaultSize)
        let frame = NSRect(origin: .zero, size: screen.frame.size)
        let source = ReaderView(frame: frame, text: text, mode: options.mode, font: font)
        let pane: ReadingPane
        switch options.mode {
        case .plain: pane = source
        case .markdown:
            // Relative links and images resolve against the file's directory; for stdin and
            // the clipboard, against the working directory.
            var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            if case .file(let path) = options.source {
                directory = URL(fileURLWithPath: path).deletingLastPathComponent()
            }
            pane = MarkdownView(
                frame: frame,
                rendered: RenderedView(
                    frame: frame, markdown: text, font: font, directory: directory),
                source: source)
        }
        window.readerView = pane
        window.title = options.source.displayName
        // Intercept key presses before the text view sees them so that
        // navigation keys scroll instead of moving an invisible caret.
        window.keyHandler = { [weak self] event in self?.handle(event) ?? false }
        window.setFrame(screen.frame, display: true)
        window.present()
        window.makeFirstResponder(pane.focusView)
        pane.scrollToTop()
        self.window = window
        self.pane = pane
        self.font = font
        sizes = Typography.sizes(forWidth: screen.frame.width)

        // Terminals do not always yield activation to a process they spawned,
        // so ask both ways. The window floats while we are active (see below)
        // so it covers the terminal even if activation is delayed.
        // (`.activateIgnoringOtherApps` has no effect since macOS 14, so it is not passed.)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate()
        if ProcessInfo.processInfo.environment["MAC_READER_DEBUG"] != nil {
            warn("screen \(screen.frame) window \(window.frame) space \(spaceMode)")
        }
    }

    /// The screen the pointer is on, which is where the user is looking when
    /// they hit return in the terminal; falls back to the main screen.
    private static func targetScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main ?? NSScreen.screens[0]
    }

    // Float above other windows only while frontmost, so the reader covers
    // everything when in use but ⌘-Tab to another app still puts it behind.
    func applicationDidBecomeActive(_ notification: Notification) {
        window?.level = .floating
    }

    func applicationDidResignActive(_ notification: Notification) {
        window?.level = .normal
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""

        // Escape dismisses (HIG: Esc cancels / exits full screen). ⌘W and ⌘Q
        // are the standard close/quit shortcuts.
        if event.keyCode == 53 {
            NSApp.terminate(nil)
            return true
        }
        if flags == .command, chars == "w" || chars == "q" {
            NSApp.terminate(nil)
            return true
        }
        // ⌘+ (also ⌘= unshifted, and keypad +) and ⌘- zoom.
        if flags.subtracting([.shift, .numericPad]) == .command {
            switch chars {
            case "+", "=":
                zoom(by: Typography.zoomStep)
                return true
            case "-":
                zoom(by: -Typography.zoomStep)
                return true
            default: break
            }
        }
        // Leave other ⌘ shortcuts (copy, select all) to the menu, except the
        // ⌘↑/⌘↓ and ⌘j/⌘k jump-to-end combinations the reader handles.
        let isArrow = event.keyCode == 125 || event.keyCode == 126
        if flags.contains(.command) && !isArrow && !(chars == "j" || chars == "k") { return false }
        guard let command = ScrollCommand(event), let pane else { return false }
        pane.scroll(command)
        return true
    }

    /// Changes the body size by `delta` points, within `sizes`.
    private func zoom(by delta: CGFloat) {
        guard let font, let pane else { return }
        let size = min(max(font.pointSize + delta, sizes.lowerBound), sizes.upperBound)
        guard size != font.pointSize,
            let zoomed = NSFont(descriptor: font.fontDescriptor, size: size)
        else { return }
        self.font = zoomed
        pane.setFont(zoomed)
        if ProcessInfo.processInfo.environment["MAC_READER_DEBUG"] != nil {
            warn("zoom \(size)pt, range \(sizes)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// A minimal menu so ⌘C / ⌘A work on selected text and Quit is reachable
    /// from the auto-hidden menu bar.
    private func installMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit mac-reader", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        NSApp.mainMenu = main
    }
}
