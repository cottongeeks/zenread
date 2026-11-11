# Zenread for agents

README.md is the user guide: what the app is, how to install it, the command
line and the keys. This file covers how it is built and how it behaves in
detail. Keep the two separate: put user-facing usage in the README and
implementation notes here.

## Platforms

Zenread is an AppKit app, so it builds only on macOS 14+ with the Swift 6
toolchain (the Command Line Tools are enough). On Linux the package is just the
AppKit-free `ReaderCore` target and its tests (see `Package.swift`), so
`make test`, `make fmt` and `make lint` also work there. Amp orbs get the Linux
toolchain from `.agents/setup`. Build, run and screenshot the app on a Mac
satellite.

## Commands

```
make debug      # swift build
make build      # swift build -c release
make app        # build/Zenread.app: Apple silicon, hardened runtime, signed
make install    # make app, then copy it to APPDIR and write the CLI script to PREFIX
make icon       # recompile the app icon (needs Xcode 26 or later)
make test       # swift test (Swift Testing)
make fmt        # swift format, config in .swift-format
make lint       # swift format lint
swift run zenread path/to/file.txt   # run without installing
```

Run `make lint` and `make test` before you finish a change.

## Build and install

- `make app` signs ad hoc, which is enough on the Mac that built it. For
  distribution use `make app SIGN_IDENTITY="Developer ID Application: …"`,
  which also timestamps the signature, then notarize the result. `VERSION` sets
  the version (default 0.1.0), and the build number is the commit count.
- `make install` defaults to `APPDIR=/Applications` and `PREFIX=~/bin`. The
  `zenread` command is a two-line script that execs the binary inside the app.
  It must not be a symlink, because macOS treats the process as Zenread (with
  its name, icon and bundle ID) only when the binary runs from its place in the
  bundle.

## Behaviour

Sources (`TextLoader.swift`, `Options.swift`):
- `FILE` is a path, or `-` for stdin, and `--` ends the options so a following
  `FILE` may start with `-`. Stdin is read only when `-` is given, so
  a launcher that leaves stdin attached to nothing still gets the clipboard.
- With no `FILE`, the reader shows the general pasteboard's text. If the
  clipboard is empty or holds only a file or image, Zenread exits with status
  66 and a message, as it does for an unreadable file. Without a terminal
  (launched from Finder, the Dock or Spotlight) these errors appear in an
  alert instead.
- `Info.plist` lists Zenread under Open With for text and Markdown files but
  does not make it their default app. Opening a file while it runs replaces
  what it shows.

Plain text (`Reflow.swift`): `--plain` reflows text hard-wrapped at 72 or 80
columns into paragraphs. Blank lines separate paragraphs, and indented lines,
list items, headings and block quotes keep their own breaks. Markdown is never
reflowed.

Markdown:
- Every source opens as Markdown, whatever its extension, unless `--plain` is
  given.
- The rendered view is GitHub Flavored Markdown from cmark-gfm (the parser
  github.com uses) in a transparent web view, including tables, task lists,
  strikethrough, autolinks and footnotes. Raw HTML passes through except for
  the tags GitHub filters (`<script>`, `<style>`, `<iframe>` and so on), and
  scripts never run. Relative images and links resolve against the file's
  directory. Links open in the default app.
- The source view shows the text exactly as written, with spans from
  swift-markdown coloured in place: headings slightly larger and bold, code in
  monospace on a faint tint, links, quotes, lists, emphasis and strikethrough
  in their own colours, and delimiters dimmed.

Typography (`Typography.swift`): the font defaults to New York and falls back
to Charter, then Georgia. Text opens at 20 points and zooms in 2 point steps,
from 12 points up to the largest size whose column still fits the screen width.
The column scales with the text, so line length stays the same.

Window (`ReaderWindow.swift`, `AppDelegate.swift`): a borderless window with a
blurred backdrop opens on the display the pointer is on. The menu bar and Dock
auto-hide while it is frontmost, and ⌘-Tab drops it behind the other app as
usual. If that display shows a full-screen app, the reader opens in a
full-screen Space of its own instead, because macOS does not let a normal
window sit over another app's full-screen Space.

## App icon

`App/AppIcon.icon` is an Icon Composer icon. macOS 26 and later draw its layers
with Liquid Glass, along with their dark, tinted and clear looks. `make icon`
compiles it with `actool` into `App/Assets.car`, which also holds flat bitmaps
for macOS 14 and 15, and into `App/AppIcon.icns`. Both outputs are committed so
`make app` works without Xcode.

The layers (`App/AppIcon.icon/Assets/*.svg`) are drawn with the vector-art
studio from `App/icon-art/scene.ts`, and `App/icon-art/brief.md` describes the
design. To change them:
1. Copy that folder to vector-art's `artworks/mac-reader-icon/`.
2. Render each layer with `LAYER=backdrop|heading|body pnpm art:render mac-reader-icon`.
3. Copy each `output/mac-reader-icon/illustration.svg` over the layer of that name.
4. Run `make icon`.

## Layout

- `Sources/Zenread/main.swift`: app bootstrap and error reporting
- `Sources/Zenread/TextLoader.swift`: file, stdin and clipboard loading with encoding detection
- `Sources/Zenread/Reflow.swift`: hard-wrap detection and paragraph reflow
- `Sources/Zenread/Typography.swift`: font selection, measure, zoom bounds, leading, paragraph spacing and the Markdown theme
- `Sources/Zenread/ReaderView.swift`: the source text view, scroll commands and the `ReadingPane` protocol
- `Sources/Zenread/RenderedView.swift`: rendered Markdown in a transparent web view
- `Sources/Zenread/MarkdownView.swift`: holds the rendered and source views and the toggle icon
- `Sources/Zenread/ReaderWindow.swift`: borderless full-screen window with a blurred backdrop
- `Sources/Zenread/AppDelegate.swift`: window setup, documents opened from Finder, the menu and key dispatch
- `Sources/ReaderCore/Options.swift`: CLI flags, the text source and the plain or Markdown mode
- `Sources/ReaderCore/MarkdownSpan.swift`: AppKit-free Markdown span extraction (swift-markdown)
- `Sources/ReaderCore/MarkdownHTML.swift`: GitHub Flavored Markdown to HTML (cmark-gfm)
- `Tests/ReaderCoreTests/`: Swift Testing tests for option parsing, span extraction and HTML rendering
- `App/`: the bundle's `Info.plist`, the icon source and the compiled icon
- `docs/`: images used by the README
