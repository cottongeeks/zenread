import AppKit
import ReaderCore

/// Wires the window, menus and the global key handling together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let options: Options
    /// The document to show when launch finishes, unmodified (`Typography.document` applies
    /// the mode): the command line's file or standard input, or a document Finder opened.
    /// Nil means the clipboard.
    private var pending: (text: String, source: Source)?
    private var window: ReaderWindow?
    private var pane: ReadingPane?
    /// The body font at the current zoom.
    private var font: NSFont?
    /// Sizes ⌘+ and ⌘- move between; the largest still fits the column on the screen.
    private var sizes: ClosedRange<CGFloat> = Typography.minimumSize...Typography.defaultSize

    init(options: Options, text: String?) {
        self.options = options
        if let text { pending = (text, options.source) }
    }

    /// Documents from Finder, the Dock or `open`: during launch when they started the app,
    /// and later when it is already running, which replaces the document on screen.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        let source = Source.file(url.path)
        do {
            let text = try TextLoader.load(source)
            if window == nil { pending = (text, source) } else { show(text, source: source) }
        } catch {
            report(error)
            if window == nil { exit(66) }  // EX_NOINPUT
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let document: (text: String, source: Source)
        if let pending {
            document = pending
        } else {
            do {
                document = (try TextLoader.load(.clipboard), .clipboard)
            } catch {
                report(error)
                exit(66)  // EX_NOINPUT
            }
        }
        pending = nil

        installMenu()
        // Hide the menu bar and Dock while we are frontmost; they come back
        // when the pointer hits the screen edge, which is standard macOS
        // full-screen behaviour.
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        let screen = Self.targetScreen()
        let spaceMode = SpaceMode.forScreen(screen)
        let window = ReaderWindow(screen: screen, spaceMode: spaceMode)
        // Intercept key presses before the text view sees them so that
        // navigation keys scroll instead of moving an invisible caret.
        window.keyHandler = { [weak self] event in self?.handle(event) ?? false }
        window.setFrame(screen.frame, display: true)
        window.present()
        self.window = window
        font = Typography.bodyFont(name: options.fontName, size: Typography.defaultSize)
        sizes = Typography.sizes(forWidth: screen.frame.width)
        show(document.text, source: document.source)

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

    /// Puts `text` in the window, replacing what it showed, at the current zoom.
    private func show(_ text: String, source: Source) {
        guard let window, let font else { return }
        let frame = NSRect(origin: .zero, size: window.frame.size)
        let sourceView = ReaderView(frame: frame, text: text, mode: options.mode, font: font)
        let pane: ReadingPane
        switch options.mode {
        case .plain: pane = sourceView
        case .markdown:
            // Relative links and images resolve against the file's directory; for stdin and
            // the clipboard, against the working directory.
            var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            if case .file(let path) = source {
                directory = URL(fileURLWithPath: path).deletingLastPathComponent()
            }
            pane = MarkdownView(
                frame: frame,
                rendered: RenderedView(
                    frame: frame, markdown: text, font: font, directory: directory),
                source: sourceView)
        }
        window.readerView = pane
        window.title = source.displayName
        window.makeFirstResponder(pane.focusView)
        pane.scrollToTop()
        self.pane = pane
    }

    /// Reports a document that cannot be shown: on stderr, and in an alert when there is no
    /// terminal to read it, as when Finder or the Dock started the app.
    private func report(_ error: Error) {
        let message = "\(error)"
        warn(message)
        guard isatty(STDERR_FILENO) == 0 else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = message.prefix(1).uppercased() + message.dropFirst() + "."
        alert.runModal()
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

        // The bundle's name in the app; the process name when run straight from `swift run`.
        let name =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ProcessInfo.processInfo.processName
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)),
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
