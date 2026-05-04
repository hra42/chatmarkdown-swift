import XCTest
@testable import ChatMarkdown

final class BlockModelTests: XCTestCase {
    func testHeadingLevels() {
        let blocks = ChatMarkdownDocument(markdown: "# A\n## B\n### C\n#### D\n##### E\n###### F").blocks
        let levels: [Int] = blocks.compactMap {
            if case .heading(let level, _) = $0 { return level } else { return nil }
        }
        XCTAssertEqual(levels, [1, 2, 3, 4, 5, 6])
    }

    func testParagraphWithBoldItalicCode() {
        let blocks = ChatMarkdownDocument(markdown: "Hello **bold** *italic* `code`").blocks
        XCTAssertEqual(blocks.count, 1)
        guard case .paragraph(let inlines) = blocks[0] else {
            return XCTFail("expected paragraph, got \(blocks[0])")
        }
        XCTAssertTrue(inlines.contains(.bold([.text("bold")])))
        XCTAssertTrue(inlines.contains(.italic([.text("italic")])))
        XCTAssertTrue(inlines.contains(.code("code")))
    }

    func testFencedCodeBlock() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        let blocks = ChatMarkdownDocument(markdown: md).blocks
        XCTAssertEqual(blocks.count, 1)
        guard case .codeBlock(let lang, let code, let isClosed) = blocks[0] else {
            return XCTFail("expected codeBlock")
        }
        XCTAssertEqual(lang, "swift")
        XCTAssertTrue(code.contains("let x = 1"))
        XCTAssertTrue(isClosed)
    }

    func testUnorderedAndOrderedLists() {
        let blocks = ChatMarkdownDocument(markdown: "- a\n- b\n\n3. x\n4. y").blocks
        XCTAssertEqual(blocks.count, 2)
        guard case .unorderedList(let uItems) = blocks[0] else {
            return XCTFail("expected unorderedList")
        }
        XCTAssertEqual(uItems.count, 2)

        guard case .orderedList(let start, let oItems) = blocks[1] else {
            return XCTFail("expected orderedList")
        }
        XCTAssertEqual(start, 3)
        XCTAssertEqual(oItems.count, 2)
    }

    func testNestedList() {
        let md = "- top\n  - nested\n    - deeper"
        let blocks = ChatMarkdownDocument(markdown: md).blocks
        guard case .unorderedList(let items) = blocks[0] else {
            return XCTFail("expected unorderedList")
        }
        // First item must contain a paragraph and a nested list.
        let first = items[0]
        XCTAssertTrue(first.contains(where: {
            if case .unorderedList = $0 { return true } else { return false }
        }), "expected nested list inside first item")
    }

    func testBlockquote() {
        let blocks = ChatMarkdownDocument(markdown: "> quoted\n> still").blocks
        guard case .blockquote(let inner) = blocks[0] else {
            return XCTFail("expected blockquote")
        }
        XCTAssertFalse(inner.isEmpty)
    }

    func testHorizontalRule() {
        let blocks = ChatMarkdownDocument(markdown: "before\n\n---\n\nafter").blocks
        XCTAssertTrue(blocks.contains(.horizontalRule))
    }

    func testLink() {
        let blocks = ChatMarkdownDocument(markdown: "[Apple](https://apple.com)").blocks
        guard case .paragraph(let inlines) = blocks[0] else {
            return XCTFail("expected paragraph")
        }
        let hasLink = inlines.contains {
            if case .link(_, let url) = $0 { return url == "https://apple.com" }
            return false
        }
        XCTAssertTrue(hasLink)
    }

    func testTable() {
        let md = """
        | A | B |
        | :- | -: |
        | 1 | 2 |
        """
        let blocks = ChatMarkdownDocument(markdown: md).blocks
        guard case .table(let headers, let rows, let alignments) = blocks[0] else {
            return XCTFail("expected table, got \(blocks)")
        }
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(alignments, [.left, .right])
    }
}
