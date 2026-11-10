# mac-reader

A minimal macOS reading view for plain text and Markdown files. Launch it from
the terminal with a file, or with no file to read the clipboard, and it fills the screen with a single, centred reading
column set in the system serif (New York) over a blur of whatever is behind it.
No chrome apart from a thin overlay scroller on the right.

```
mac-reader README.md               # rendered Markdown; the corner icon shows the source
cat notes.md | mac-reader -        # standard input
mac-reader                         # no FILE: show the text on the clipboard
mac-reader -- -notes.txt           # a file whose name starts with '-'
mac-reader --plain notes.txt       # plain text, hard-wrapped lines reflowed
mac-reader --font Charter book.md
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--font NAME` | New York | Font family or face; falls back to Charter, then Georgia |
| `--plain` | Markdown | Show the text as plain text instead of Markdown |
| `--` | | End of options; a following FILE may start with `-` |

Text opens at 20 points; `⌘+` and `⌘-` zoom it in 2 point steps. The reading
column scales with the text, so lines keep their length, from 12 points up to
the largest size whose column still fits the screen width.

## Sources

`FILE` is a path, or `-` for standard input. With no `FILE`, the reader shows
the text on the clipboard (the general pasteboard), which suits a global hotkey
or launcher. Stdin is only read when asked for with `-`, so a launcher that
leaves stdin attached to nothing still gets the clipboard. An empty clipboard,
or one holding only a file or image, exits with status 66 and a message, like
an unreadable file does.

With `--plain`, hard-wrapped text (wrapped at 72/80 columns) is reflowed into
paragraphs so it reads naturally at the wider measure. Blank lines separate
paragraphs; indented lines, list items, headings and block quotes keep their own
breaks.

## Markdown

Every source, whatever its extension, opens as Markdown unless `--plain` is
given. Markdown opens rendered, as GitHub Flavored Markdown: tables, task lists,
strikethrough, autolinks and footnotes, set in the same reading column and
colours. It is rendered by cmark-gfm, the parser github.com uses, and raw HTML
passes through apart from the tags GitHub filters (`<script>`, `<style>`,
`<iframe>` and so on); scripts never run. Relative images and links resolve
against the file's directory. Links open in the default app.

A small icon in the top-right corner switches to the source view and back.
The source is shown exactly as written, with `#`, `*`, backticks,
`[text](url)`, `>` and list markers all on screen and coloured in place:
headings slightly larger and bold, code in monospace on a faint tint, links,
quotes, lists, emphasis and strikethrough in their own colours, delimiters
dimmed. Long lines still wrap at the column width. Markdown is never reflowed.

## Keys

| Key | Action |
| --- | --- |
| `Esc`, `⌘W`, `⌘Q` | Close |
| `Space` / `Shift-Space`, `PgDn` / `PgUp`, `f` / `b`, `d` / `u` | Page down / up |
| `↓` / `↑`, `j` / `k` | Line down / up |
| `Home` / `End`, `g` / `G`, `⌘↑` / `⌘↓` | Top / bottom |
| `⌘+` (or `⌘=`) / `⌘-` | Zoom in / out |
| `⌘C`, `⌘A` | Copy selection, select all |

The reader opens on the display the mouse pointer is on. The menu bar and Dock
auto-hide while it is frontmost; move the pointer to the top of the screen to
get the menu bar back. ⌘-Tab to another app drops it behind that app as usual.
If that display is showing a full-screen app, the reader opens in a full-screen
Space of its own instead, since macOS does not let a normal window sit over
another app's full-screen Space. Escape closes it as usual.

## Development

Requires the Swift 6 toolchain (Xcode Command Line Tools are enough) on macOS 14+.
On Linux the package is just `ReaderCore` and its tests, so `make test` and
`make lint` work there too; Amp orbs set that up with `.agents/setup`.

```
make debug      # swift build
make build      # swift build -c release  -> .build/release/mac-reader
make install    # copy the release binary to ~/bin (override with PREFIX=...)
make test       # swift test (Swift Testing; Command Line Tools are enough)
make fmt        # swift format, config in .swift-format
make lint       # swift format lint
```

Run without installing:

```
swift run mac-reader path/to/file.txt
```

## Layout

- `Sources/MacReader/main.swift` – app bootstrap and error reporting
- `TextLoader.swift` – file / stdin / clipboard loading with encoding detection
- `Reflow.swift` – hard-wrap detection and paragraph reflow
- `Typography.swift` – font selection, measure, zoom bounds, leading, paragraph spacing, Markdown theme
- `ReaderView.swift` – source text view, scroll commands, the `ReadingPane` protocol
- `RenderedView.swift` – rendered Markdown in a transparent web view
- `MarkdownView.swift` – holds the rendered and source views and the toggle icon
- `ReaderWindow.swift` – borderless full-screen window with a blurred backdrop
- `AppDelegate.swift` – window setup, menu, key dispatch
- `Sources/ReaderCore/Options.swift` – CLI flags, the text source and the plain / Markdown mode
- `Sources/ReaderCore/MarkdownSpan.swift` – AppKit-free Markdown span extraction (swift-markdown)
- `Sources/ReaderCore/MarkdownHTML.swift` – GitHub Flavored Markdown to HTML (cmark-gfm)
- `Tests/ReaderCoreTests/` – Swift Testing tests for option parsing, span extraction and HTML rendering
