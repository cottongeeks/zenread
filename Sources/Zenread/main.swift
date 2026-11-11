import AppKit
import ReaderCore

/// Writes "zenread: message" to stderr.
func warn(_ message: String) {
    FileHandle.standardError.write(Data("zenread: \(message)\n".utf8))
}

// Entry point. Parse arguments and load the text before touching AppKit so
// that errors surface on the terminal instead of in a half-launched app.

let options: Options
do {
    switch try Options.parse(Array(CommandLine.arguments.dropFirst())) {
    case .help:
        print(Options.usage)
        exit(0)
    case .read(let parsed):
        options = parsed
    }
} catch {
    warn("\(error)\n\n\(Options.usage)")
    exit(64)  // EX_USAGE
}

// A file or standard input loads now, so its errors reach the terminal before the app
// starts. The clipboard waits for launch to finish: when Finder or `open` starts the app
// with a document, the document arrives during launch and is shown instead.
var text: String?
if options.source != .clipboard {
    do {
        text = try TextLoader.load(options.source)
    } catch {
        warn("\(error)")
        exit(66)  // EX_NOINPUT
    }
}

let app = NSApplication.shared
// Regular policy so the app can become active and own key focus when
// launched from a terminal; the Dock icon is hidden by presentation options.
app.setActivationPolicy(.regular)
let delegate = AppDelegate(options: options, text: text)
app.delegate = delegate
app.run()
