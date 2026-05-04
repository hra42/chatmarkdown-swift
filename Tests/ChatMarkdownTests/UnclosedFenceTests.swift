import XCTest
@testable import ChatMarkdown

final class UnclosedFenceTests: XCTestCase {
    func test_unclosed_trailing_fence_marks_isClosed_false() {
        let md = """
        intro

        ```python
        def hi():
            print("x")
        """
        let doc = ChatMarkdownDocument(markdown: md)
        guard case let .codeBlock(language, _, isClosed) = doc.blocks.last else {
            return XCTFail("expected trailing codeBlock, got \(String(describing: doc.blocks.last))")
        }
        XCTAssertEqual(language, "python")
        XCTAssertFalse(isClosed)
    }

    func test_closed_fence_remains_isClosed_true() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        let doc = ChatMarkdownDocument(markdown: md)
        guard case let .codeBlock(_, _, isClosed) = doc.blocks.last else {
            return XCTFail("expected codeBlock")
        }
        XCTAssertTrue(isClosed)
    }

    func test_multiple_fences_only_last_marked_open() {
        let md = """
        ```swift
        let x = 1
        ```

        between

        ```python
        y = 2
        """
        let doc = ChatMarkdownDocument(markdown: md)
        var codeBlocks: [(String?, Bool)] = []
        for b in doc.blocks {
            if case let .codeBlock(lang, _, isClosed) = b {
                codeBlocks.append((lang, isClosed))
            }
        }
        XCTAssertEqual(codeBlocks.count, 2)
        XCTAssertEqual(codeBlocks[0].0, "swift")
        XCTAssertTrue(codeBlocks[0].1)
        XCTAssertEqual(codeBlocks[1].0, "python")
        XCTAssertFalse(codeBlocks[1].1)
    }

    func test_unclosed_inline_emphasis_renders_as_literal_text() {
        // CommonMark: unmatched ** is emitted as literal text.
        // chatmarkdown does not deviate. Lock behavior so streaming callers can
        // rely on "no closing token → no styled span yet."
        let md = "Some **unfinished bold"
        let doc = ChatMarkdownDocument(markdown: md)
        guard case let .paragraph(inlines) = doc.blocks.first else {
            return XCTFail("expected paragraph, got \(String(describing: doc.blocks.first))")
        }
        // No .bold node should appear anywhere in the inlines.
        XCTAssertFalse(containsBold(inlines), "unmatched ** must not produce a .bold span")
        // The literal asterisks must survive in the rendered text.
        let flat = flatText(inlines)
        XCTAssertTrue(flat.contains("**"), "expected literal '**' in flattened text, got \(flat)")
        XCTAssertTrue(flat.contains("unfinished bold"), "expected trailing text preserved, got \(flat)")
    }

    private func containsBold(_ inlines: [ChatMarkdownInline]) -> Bool {
        for x in inlines {
            switch x {
            case .bold: return true
            case .italic(let inner), .link(let inner, _):
                if containsBold(inner) { return true }
            default: continue
            }
        }
        return false
    }

    private func flatText(_ inlines: [ChatMarkdownInline]) -> String {
        var s = ""
        for x in inlines {
            switch x {
            case .text(let t): s += t
            case .code(let c): s += c
            case .bold(let inner), .italic(let inner): s += flatText(inner)
            case .link(let inner, _): s += flatText(inner)
            case .lineBreak: s += "\n"
            }
        }
        return s
    }
}
