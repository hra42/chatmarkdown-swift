import XCTest
@testable import ChatMarkdown

// These inputs all previously crashed the third-party MarkdownView's
// RangeAdjuster, forcing a sanitization pre-pass. With our own normalizer
// over swift-markdown directly, the inputs must parse cleanly without any
// sanitization layer.
final class EdgeCaseTests: XCTestCase {
    func testEmptyString() {
        XCTAssertEqual(ChatMarkdownDocument(markdown: "").blocks, [])
    }

    func testWhitespaceOnly() {
        XCTAssertEqual(ChatMarkdownDocument(markdown: "   \n   \n").blocks, [])
    }

    func testLoneHash() {
        // `# ` with no content — accept whatever the parser produces, just don't crash.
        _ = ChatMarkdownDocument(markdown: "#").blocks
        _ = ChatMarkdownDocument(markdown: "# ").blocks
    }

    func testTabs() {
        let blocks = ChatMarkdownDocument(markdown: "\tHello\tWorld").blocks
        // Tabs trigger code-block interpretation in CommonMark when leading;
        // mid-line tabs end up as paragraph text. Either way: no crash.
        XCTAssertFalse(blocks.isEmpty)
    }

    func testCarriageReturnNewlines() {
        let blocks = ChatMarkdownDocument(markdown: "Line1\r\nLine2").blocks
        XCTAssertFalse(blocks.isEmpty)
    }

    func testBareCarriageReturns() {
        // `\r` alone (old Mac line endings) — must not crash.
        let blocks = ChatMarkdownDocument(markdown: "Line1\rLine2").blocks
        XCTAssertFalse(blocks.isEmpty)
    }

    func testTabsAndCRLFCombined() {
        let blocks = ChatMarkdownDocument(markdown: "\tCode\r\n\tMore").blocks
        XCTAssertFalse(blocks.isEmpty)
    }

    func testTrailingCarriageReturn() {
        let blocks = ChatMarkdownDocument(markdown: "text\r").blocks
        XCTAssertFalse(blocks.isEmpty)
    }

    func testCarriageReturnFollowedByTab() {
        let blocks = ChatMarkdownDocument(markdown: "a\r\tb").blocks
        XCTAssertFalse(blocks.isEmpty)
    }

    func testUnclosedCodeFence() {
        let md = "```python\ndef hello():\n    print(\"hi\")"
        let blocks = ChatMarkdownDocument(markdown: md).blocks
        XCTAssertEqual(blocks.count, 1)
        guard case .codeBlock(let lang, let code, _) = blocks[0] else {
            return XCTFail("expected unclosed fence to still produce a codeBlock")
        }
        XCTAssertEqual(lang, "python")
        XCTAssertTrue(code.contains("def hello"))
    }

    func testUnclosedBoldRendersAsText() {
        // Mid-stream: bold marker opened but not closed yet.
        let blocks = ChatMarkdownDocument(markdown: "Hello **world").blocks
        guard case .paragraph(let inlines) = blocks[0] else {
            return XCTFail("expected paragraph")
        }
        // No bold should be present — the `**` is unmatched and rendered as text.
        let hasBold = inlines.contains {
            if case .bold = $0 { return true } else { return false }
        }
        XCTAssertFalse(hasBold)
    }

    func testHTMLBlockDropped() {
        let blocks = ChatMarkdownDocument(markdown: "<div>hi</div>").blocks
        // HTML blocks are not in our supported set; they must be dropped silently.
        XCTAssertTrue(blocks.isEmpty || !blocks.contains(where: {
            if case .paragraph(let xs) = $0 { return xs.contains(.text("<div>hi</div>")) }
            return false
        }))
    }
}
