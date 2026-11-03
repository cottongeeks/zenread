import ReaderCore
import Testing

/// Expected HTML is taken from the GFM spec's examples (https://github.github.com/gfm/).
@Test(arguments: [
    // Tables (spec example 198).
    (
        "| foo | bar |\n| --- | --- |\n| baz | bim |",
        "<table>\n<thead>\n<tr>\n<th>foo</th>\n<th>bar</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>baz</td>\n<td>bim</td>\n</tr>\n</tbody>\n</table>\n"
    ),
    // Strikethrough (491).
    ("~~Hi~~ Hello, world!", "<p><del>Hi</del> Hello, world!</p>\n"),
    // Task list items (279).
    (
        "- [ ] foo\n- [x] bar",
        "<ul>\n<li><input type=\"checkbox\" disabled=\"\" /> foo</li>\n<li><input type=\"checkbox\" checked=\"\" disabled=\"\" /> bar</li>\n</ul>\n"
    ),
    // Extended www autolink (621).
    (
        "www.commonmark.org",
        "<p><a href=\"http://www.commonmark.org\">www.commonmark.org</a></p>\n"
    ),
    // Disallowed raw HTML is escaped; other raw HTML passes through (652).
    ("<strong> <title> <style> <em>", "<p><strong> &lt;title> &lt;style> <em></p>\n"),
    // Code is escaped, not parsed as HTML.
    ("`a<b>`", "<p><code>a&lt;b&gt;</code></p>\n"),
])
func rendersGitHubFlavoredMarkdown(markdown: String, html: String) {
    #expect(MarkdownHTML.body(markdown) == html)
}

@Test func rendersFootnotes() {
    let html = MarkdownHTML.body("Note[^1].\n\n[^1]: Detail.")
    #expect(html.contains("<sup class=\"footnote-ref\"><a href=\"#fn-1\""))
    #expect(html.contains("<li id=\"fn-1\">"))
}
