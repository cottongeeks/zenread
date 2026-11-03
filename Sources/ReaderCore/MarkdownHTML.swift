import Foundation
import cmark_gfm
import cmark_gfm_extensions

/// GitHub Flavored Markdown to HTML, rendered by cmark-gfm, the parser github.com uses.
public enum MarkdownHTML {
    /// The GFM extensions github.com enables. `tagfilter` escapes the raw HTML tags GFM
    /// disallows (`<script>`, `<iframe>`, `<style>` and so on).
    static let extensions = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"]

    /// The HTML body for `markdown`. Raw HTML in the source passes through, apart from the
    /// tags `tagfilter` escapes, as on github.com.
    public static func body(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        let options = CMARK_OPT_UNSAFE | CMARK_OPT_FOOTNOTES | CMARK_OPT_GITHUB_PRE_LANG
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }
        for name in extensions {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }
        var source = markdown
        source.withUTF8 { cmark_parser_feed(parser, $0.baseAddress, $0.count) }
        guard let document = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(document) }
        guard
            let html = cmark_render_html(
                document, options, cmark_parser_get_syntax_extensions(parser))
        else { return "" }
        defer { free(html) }
        return String(cString: html)
    }
}
