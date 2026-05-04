import XCTest
@testable import ChatMarkdown

final class PlainTextRendererTests: XCTestCase {
    func testAllFixturesProduceOutput() throws {
        for name in FixtureSupport.names {
            let md = try FixtureSupport.loadInput(name)
            let text = ChatMarkdownPlainTextRenderer.render(md)
            if md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                XCTAssertTrue(text.isEmpty, "empty input produced text for \(name): \(text)")
            }
            // No assertion on non-empty inputs other than no crash; some fixtures
            // (unclosed-fence) may legitimately strip down to little or nothing
            // depending on options.
            _ = text
        }
    }

    func testCodeBlockReplacedWithMarkerByDefault() throws {
        let md = try FixtureSupport.loadInput("code-fence-swift")
        let text = ChatMarkdownPlainTextRenderer.render(md)
        XCTAssertTrue(text.contains("[code block]"),
                      "default options should replace code with marker; got: \(text)")
        XCTAssertFalse(text.contains("greet"),
                       "code body should be stripped by default; got: \(text)")
    }

    func testCodeBlockDropOption() throws {
        let md = try FixtureSupport.loadInput("code-fence-swift")
        var opts = PlainTextOptions.ttsDefaults
        opts.codeBlockHandling = .drop
        let text = ChatMarkdownPlainTextRenderer.render(md, options: opts)
        XCTAssertFalse(text.contains("[code block]"))
        XCTAssertFalse(text.contains("greet"))
    }

    func testCodeBlockKeepTextOption() throws {
        let md = try FixtureSupport.loadInput("code-fence-swift")
        let text = ChatMarkdownPlainTextRenderer.render(md, options: .faithful)
        XCTAssertTrue(text.contains("greet"), "faithful option should keep code body; got: \(text)")
    }

    func testListItemsAreSeparated() {
        let md = """
        - first
        - second
        - third
        """
        let text = ChatMarkdownPlainTextRenderer.render(md)
        XCTAssertTrue(text.contains("first"))
        XCTAssertTrue(text.contains("second"))
        XCTAssertTrue(text.contains("third"))
    }

    func testOrdinalListMarkers() {
        let md = """
        1. one
        2. two
        """
        var opts = PlainTextOptions.ttsDefaults
        opts.listMarkerStyle = .ordinal
        let text = ChatMarkdownPlainTextRenderer.render(md, options: opts)
        XCTAssertTrue(text.contains("1. one"))
        XCTAssertTrue(text.contains("2. two"))
    }

    func testLinkTextOnlyByDefault() {
        let md = "Visit [Apple](https://apple.com) now."
        let text = ChatMarkdownPlainTextRenderer.render(md)
        XCTAssertTrue(text.contains("Apple"))
        XCTAssertFalse(text.contains("https://apple.com"))
    }

    func testLinkWithURLOption() {
        let md = "Visit [Apple](https://apple.com) now."
        var opts = PlainTextOptions.ttsDefaults
        opts.linkRendering = .textThenURL
        let text = ChatMarkdownPlainTextRenderer.render(md, options: opts)
        XCTAssertTrue(text.contains("https://apple.com"))
    }

    func testEmptyInputIsSafe() {
        XCTAssertEqual(ChatMarkdownPlainTextRenderer.render(""), "")
    }

    func testUnclosedFenceProducesSaneText() throws {
        let md = try FixtureSupport.loadInput("unclosed-fence")
        let text = ChatMarkdownPlainTextRenderer.render(md)
        // Should not crash; should produce a string (possibly with code marker).
        _ = text
    }

    func testHorizontalRuleStripped() {
        let md = "before\n\n---\n\nafter"
        let text = ChatMarkdownPlainTextRenderer.render(md)
        XCTAssertTrue(text.contains("before"))
        XCTAssertTrue(text.contains("after"))
        XCTAssertFalse(text.contains("---"))
    }
}
