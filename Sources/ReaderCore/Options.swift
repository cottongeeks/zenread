import Foundation

/// How the loaded text becomes the displayed document. Chosen once in `Options.parse`;
/// `Typography.document` is the only code that interprets it.
public enum TextMode: Equatable, Sendable {
    /// Body styling, with hard-wrapped lines joined into paragraphs.
    case plain
    /// Rendered Markdown, with the source (syntax coloured in place) a click away.
    case markdown
}

/// Where the text comes from.
public enum Source: Equatable, Sendable {
    case file(String)
    /// FILE given as `-`.
    case standardInput
    /// No FILE given.
    case clipboard

    /// Window title: the file name, or what the source is.
    public var displayName: String {
        switch self {
        case .file(let path): return (path as NSString).lastPathComponent
        case .standardInput: return "Standard Input"
        case .clipboard: return "Clipboard"
        }
    }
}

/// Parsed command-line options. See `usage` for the flags.
public struct Options: Equatable, Sendable {
    public var source: Source
    /// Font family override; nil means the built-in preference list is used.
    public var fontName: String?
    public var mode: TextMode = .markdown

    /// What the command line asks for.
    public enum Invocation: Equatable, Sendable {
        case read(Options)
        case help
    }

    /// An invalid command line; `description` is the message for stderr.
    public struct UsageError: Error, Equatable, CustomStringConvertible {
        public let description: String
    }

    public static let usage = """
        usage: zenread [options] [FILE]

          FILE            text file to display, or '-' to read standard input;
                          without FILE the text on the clipboard is shown
          --font NAME     font family (default: New York, falling back to Charter, Georgia)
          --plain         show the text as plain text instead of Markdown
          --              end of options, for a FILE whose name starts with '-'

        Press ⌘+ and ⌘- to zoom, Escape, ⌘W or ⌘Q to close.
        """

    /// Parses `args` (excluding the program name).
    public static func parse(_ args: [String]) throws(UsageError) -> Invocation {
        var fontName: String?
        var mode = TextMode.markdown
        var source: Source?
        var optionsEnded = false

        func setSource(_ s: Source) throws(UsageError) {
            if source != nil { throw UsageError(description: "only one file may be given") }
            source = s
        }

        var it = args.makeIterator()
        while let arg = it.next() {
            if arg == "-" {
                try setSource(.standardInput)
                continue
            }
            if optionsEnded || !arg.hasPrefix("-") {
                try setSource(.file(arg))
                continue
            }
            switch arg {
            case "-h", "--help":
                return .help
            case "--":
                optionsEnded = true
            case "--font":
                guard let v = it.next() else {
                    throw UsageError(description: "--font requires a value")
                }
                fontName = v
            case "--plain":
                mode = .plain
            default:
                throw UsageError(description: "unknown option \(arg)")
            }
        }

        return .read(Options(source: source ?? .clipboard, fontName: fontName, mode: mode))
    }
}
