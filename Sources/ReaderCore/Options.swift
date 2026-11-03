import Foundation

/// How the loaded text becomes the displayed document. Chosen once in `Options.parse`;
/// `Typography.document` is the only code that interprets it.
public enum TextMode: Equatable, Sendable {
    /// Body styling; `reflow` joins hard-wrapped lines.
    case plain(reflow: Bool)
    /// The source verbatim with its Markdown syntax coloured in place. Never reflowed.
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
    /// Body text size in points.
    public var fontSize: CGFloat = 20
    public var mode: TextMode = .plain(reflow: true)
    /// Opacity of the dark backdrop tint, 0 (clear) to 1 (solid).
    public var opacity: CGFloat = 0.80
    /// Whether to blur what is behind the window.
    public var blur = true

    /// What the command line asks for.
    public enum Invocation: Equatable, Sendable {
        case read(Options)
        case help
    }

    /// An invalid command line; `description` is the message for stderr.
    public struct UsageError: Error, Equatable, CustomStringConvertible {
        public let description: String
    }

    /// Lowercased extensions that open in Markdown mode unless --plain is given.
    public static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    public static let usage = """
        usage: mac-reader [options] [FILE]

          FILE            text file to display, or '-' to read standard input;
                          without FILE the text on the clipboard is shown
          --font NAME     font family (default: New York, falling back to Charter, Georgia)
          --size POINTS   body text size in points (default: 20)
          --opacity N     backdrop opacity from 0 to 1 (default: 0.8)
          --no-blur       do not blur what is behind the window
          --markdown      show the text as Markdown (default for .md .markdown .mdown .mkd)
          --plain         show the text as plain text, even with a Markdown extension
          --no-reflow     keep the text's own line breaks instead of reflowing
                          hard-wrapped paragraphs (Markdown is never reflowed)
          --              end of options, for a FILE whose name starts with '-'

        Standard input and the clipboard are plain text unless --markdown is given.
        Press Escape, ⌘W or ⌘Q to close.
        """

    /// Parses `args` (excluding the program name).
    public static func parse(_ args: [String]) throws(UsageError) -> Invocation {
        var fontName: String?
        var fontSize: CGFloat = 20
        var reflow = true
        var markdown: Bool?
        var opacity: CGFloat = 0.80
        var blur = true
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
            case "--size":
                guard let v = it.next(), let n = Double(v), n.isFinite, n > 0 else {
                    throw UsageError(description: "--size requires a positive number")
                }
                fontSize = CGFloat(n)
            case "--opacity":
                guard let v = it.next(), let n = Double(v), (0...1).contains(n) else {
                    throw UsageError(description: "--opacity requires a number between 0 and 1")
                }
                opacity = CGFloat(n)
            case "--no-blur":
                blur = false
            case "--no-reflow":
                reflow = false
            case "--markdown", "--plain":
                let wantsMarkdown = arg == "--markdown"
                if markdown == !wantsMarkdown {
                    throw UsageError(description: "--markdown and --plain are mutually exclusive")
                }
                markdown = wantsMarkdown
            default:
                throw UsageError(description: "unknown option \(arg)")
            }
        }

        let resolved = source ?? .clipboard
        var isMarkdown = markdown ?? false
        if markdown == nil, case .file(let path) = resolved {
            isMarkdown = markdownExtensions.contains((path as NSString).pathExtension.lowercased())
        }
        return .read(
            Options(
                source: resolved, fontName: fontName, fontSize: fontSize,
                mode: isMarkdown ? .markdown : .plain(reflow: reflow), opacity: opacity,
                blur: blur))
    }
}
