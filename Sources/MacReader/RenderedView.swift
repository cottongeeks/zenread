import AppKit
import ReaderCore
import UniformTypeIdentifiers
import WebKit

/// Markdown rendered to HTML (GitHub Flavored Markdown) in a transparent web view, styled to
/// match the source view's typography and colours.
final class RenderedView: WKWebView, ReadingPane, WKNavigationDelegate {
    /// One-line scroll step in CSS pixels, which `pageZoom` does not change.
    private let lineStep: CGFloat
    /// The body size the page is written for; `setFont` zooms the page relative to it.
    private let pageSize: CGFloat

    /// Relative links and images resolve against `directory`.
    init(frame: NSRect, markdown: String, font: NSFont, directory: URL) {
        lineStep = font.pointSize * Typography.leading
        pageSize = font.pointSize
        let configuration = WKWebViewConfiguration()
        // The page needs no scripts of its own; the app's evaluateJavaScript calls still run.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.setURLSchemeHandler(LocalFiles(), forURLScheme: LocalFiles.scheme)
        super.init(frame: frame, configuration: configuration)
        // Let the blurred backdrop show through.
        setValue(false, forKey: "drawsBackground")
        underPageBackgroundColor = .clear
        navigationDelegate = self
        loadHTMLString(
            Self.page(body: MarkdownHTML.body(markdown), font: font),
            baseURL: LocalFiles.url(for: directory))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    // MARK: ReadingPane

    var focusView: NSView { self }

    func scroll(_ command: ScrollCommand) {
        // Scripts measure in CSS pixels, each `pageZoom` points.
        let page = bounds.height * ScrollCommand.pageFraction / pageZoom
        let script: String
        switch command {
        case .pageDown: script = "window.scrollBy({top: \(page), behavior: 'smooth'})"
        case .pageUp: script = "window.scrollBy({top: \(-page), behavior: 'smooth'})"
        case .lineDown: script = "window.scrollBy({top: \(lineStep), behavior: 'smooth'})"
        case .lineUp: script = "window.scrollBy({top: \(-lineStep), behavior: 'smooth'})"
        case .top: script = "window.scrollTo({top: 0, behavior: 'smooth'})"
        case .bottom:
            script = "window.scrollTo({top: document.body.scrollHeight, behavior: 'smooth'})"
        }
        evaluateJavaScript(script)
    }

    func scrollToTop() { evaluateJavaScript("window.scrollTo(0, 0)") }

    /// Page zoom scales the text, the column and its margins together, the way browser zoom
    /// does; the column still never grows past the window.
    func setFont(_ font: NSFont) { pageZoom = font.pointSize / pageSize }

    // MARK: Links

    /// In-page links (footnotes) navigate within the page; every other link opens in the
    /// default app instead of replacing the document.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async
        -> WKNavigationActionPolicy
    {
        guard navigationAction.navigationType == .linkActivated,
            let url = navigationAction.request.url
        else { return .allow }
        if let current = webView.url, Self.withoutFragment(url) == Self.withoutFragment(current) {
            return .allow
        }
        NSWorkspace.shared.open(LocalFiles.fileURL(for: url) ?? url)
        return .cancel
    }

    private static func withoutFragment(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.fragment = nil
        return components?.url
    }

    // MARK: Page

    /// CSS `font-family` for `font`. New York's family name is private, and `ui-serif` is
    /// how WebKit names it.
    private static func cssFamily(_ font: NSFont) -> String {
        let fallbacks = "ui-serif, Charter, Georgia, serif"
        guard let family = font.familyName, !family.hasPrefix(".") else { return fallbacks }
        return "\"\(family)\", \(fallbacks)"
    }

    /// The colours mirror `Typography`'s Markdown theme.
    private static func page(body: String, font: NSFont) -> String {
        let size = font.pointSize
        return """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8">
            <style>
            :root { color-scheme: dark; }
            html, body { background: transparent; margin: 0; }
            body {
                font-family: \(cssFamily(font)); font-size: \(size)px; line-height: \(Typography.leading);
                color: rgb(219 219 219); max-width: \(Typography.measure(size: size))px; margin: 0 auto;
                padding: 12vh \(Typography.margin)px 20vh; overflow-wrap: break-word;
                font-kerning: normal; font-variant-ligatures: common-ligatures;
            }
            ::selection { background: rgb(255 255 255 / 0.18); }
            p, ul, ol, blockquote, pre, table, hr, details { margin: 0 0 0.9em; }
            h1, h2, h3, h4, h5, h6 {
                color: rgb(245 209 153); font-weight: bold; line-height: 1.3; margin: 1.4em 0 0.5em;
            }
            body > :first-child { margin-top: 0; }
            h1 { font-size: 1.5em; } h2 { font-size: 1.3em; } h3 { font-size: 1.15em; }
            h4, h5, h6 { font-size: 1em; }
            em { color: rgb(219 204 245); }
            strong { color: rgb(247 247 247); }
            del { color: rgb(153 153 153); }
            a { color: rgb(135 191 255); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code, pre {
                font-family: ui-monospace, Menlo, monospace; font-size: \(Typography.codeScale)em;
                color: rgb(168 222 179); background: rgb(255 255 255 / 0.06); border-radius: 4px;
            }
            code { padding: 0.1em 0.3em; }
            pre { padding: 0.8em 1em; overflow-x: auto; line-height: 1.45; }
            pre code { font-size: 1em; padding: 0; background: none; }
            blockquote {
                color: rgb(179 194 209); margin-left: 0; padding-left: 1em;
                border-left: 3px solid rgb(255 255 255 / 0.15);
            }
            ul, ol { padding-left: 1.6em; }
            li::marker { color: rgb(242 173 107); }
            li > p { margin: 0 0 0.4em; }
            li:has(> input[type=checkbox]) { list-style: none; margin-left: -1.4em; }
            input[type=checkbox] { accent-color: rgb(242 173 107); margin: 0 0.4em 0 0; }
            hr { border: none; border-top: 1px solid rgb(115 115 115); margin: 1.6em 0; }
            table { border-collapse: collapse; display: block; overflow-x: auto; }
            th, td { border: 1px solid rgb(255 255 255 / 0.15); padding: 0.3em 0.7em; }
            th { color: rgb(247 247 247); background: rgb(255 255 255 / 0.04); }
            img { max-width: 100%; }
            .footnotes { font-size: 0.85em; color: rgb(180 180 180); }
            </style></head>
            <body>
            \(body)
            </body></html>
            """
    }
}

/// Serves local files to the page under a private scheme. A page loaded with
/// `loadHTMLString` gets no reliable read access to `file:` URLs, so relative images would
/// not load; this scheme reads them on the app's behalf.
@MainActor
private final class LocalFiles: NSObject, WKURLSchemeHandler {
    static let scheme = "reader-file"

    /// `directory` as a base URL under this scheme, ending in "/" so relative paths resolve
    /// inside it.
    static func url(for directory: URL) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "local"
        components.path = directory.standardizedFileURL.path + "/"
        return components.url
    }

    /// The file a URL under this scheme names; nil for any other URL.
    static func fileURL(for url: URL) -> URL? {
        url.scheme == scheme ? URL(fileURLWithPath: url.path) : nil
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, let file = Self.fileURL(for: url),
            let data = try? Data(contentsOf: file)
        else { return task.didFailWithError(URLError(.fileDoesNotExist)) }
        let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType
        task.didReceive(
            URLResponse(
                url: url, mimeType: mime ?? "application/octet-stream",
                expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
