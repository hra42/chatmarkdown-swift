import XCTest
@testable import ChatMarkdown

final class HTMLRendererTests: XCTestCase {
    func testAllFixturesProduceOutput() throws {
        for name in FixtureSupport.names {
            let md = try FixtureSupport.loadInput(name)
            let html = ChatMarkdownHTMLRenderer.render(md, embedStyles: false)
            if md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                XCTAssertTrue(html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              "empty input produced HTML for \(name): \(html)")
            } else {
                XCTAssertFalse(html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               "no HTML for \(name)")
            }
        }
    }

    func testHeadingsRenderTags() throws {
        let html = ChatMarkdownHTMLRenderer.render(try FixtureSupport.loadInput("headings"), embedStyles: false)
        XCTAssertTrue(html.contains("<h1>"))
    }

    func testCodeBlockRendersPreCode() throws {
        let html = ChatMarkdownHTMLRenderer.render(try FixtureSupport.loadInput("code-fence-swift"), embedStyles: false)
        XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">"),
                      "expected language-tagged pre/code; got: \(html)")
        XCTAssertTrue(html.contains("greet"))
        XCTAssertTrue(html.contains("</code></pre>"))
    }

    func testTableRendersTableTags() throws {
        let html = ChatMarkdownHTMLRenderer.render(try FixtureSupport.loadInput("gfm-table"), embedStyles: false)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<thead>"))
        XCTAssertTrue(html.contains("<tbody>"))
        XCTAssertTrue(html.contains("<th"))
        XCTAssertTrue(html.contains("<td"))
        XCTAssertTrue(html.contains("Alice"))
    }

    func testBlockquoteRendersBlockquoteTag() throws {
        let html = ChatMarkdownHTMLRenderer.render(try FixtureSupport.loadInput("blockquote"), embedStyles: false)
        XCTAssertTrue(html.contains("<blockquote>"))
    }

    func testNestedListRendersUlOrOl() throws {
        let html = ChatMarkdownHTMLRenderer.render(try FixtureSupport.loadInput("nested-list"), embedStyles: false)
        XCTAssertTrue(html.contains("<ul>") || html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>"))
    }

    func testEscapingHandlesSpecials() {
        let html = ChatMarkdownHTMLRenderer.render("a < b & c > d \"x\"", embedStyles: false)
        XCTAssertTrue(html.contains("&lt;"), "got: \(html)")
        XCTAssertTrue(html.contains("&gt;"), "got: \(html)")
        XCTAssertTrue(html.contains("&amp;"), "got: \(html)")
        // swift-markdown may convert straight quotes via smart-typography; allow
        // either escaped form, raw quote (unlikely), or smart-quote replacements.
        let hasQuoteForm = html.contains("&quot;")
            || html.contains("\"")
            || html.contains("&#8220;") || html.contains("&#8221;")
            || html.contains("\u{201C}") || html.contains("\u{201D}")
        XCTAssertTrue(hasQuoteForm, "expected some quote form in: \(html)")
    }

    func testRawQuoteInPlainTextEscapes() {
        // Force a quote into a context where smart-typography won't touch it
        // (inline code preserves the literal character).
        let html = ChatMarkdownHTMLRenderer.render("`a\"b`", embedStyles: false)
        XCTAssertTrue(html.contains("&quot;"), "got: \(html)")
    }

    func testLinkRendersAnchorWithEscapedHref() {
        let html = ChatMarkdownHTMLRenderer.render("[Apple](https://apple.com)", embedStyles: false)
        XCTAssertTrue(html.contains("<a href=\"https://apple.com\">Apple</a>"),
                      "got: \(html)")
    }

    func testEmbedStylesPrependsStyleBlock() {
        let html = ChatMarkdownHTMLRenderer.render("hello", embedStyles: true)
        XCTAssertTrue(html.hasPrefix("<style>"))
    }

    func testEmptyInputIsSafe() {
        let html = ChatMarkdownHTMLRenderer.render("", embedStyles: false)
        XCTAssertEqual(html.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }
}
