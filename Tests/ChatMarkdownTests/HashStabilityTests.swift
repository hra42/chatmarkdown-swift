import XCTest
@testable import ChatMarkdown

final class HashStabilityTests: XCTestCase {
    func testIdenticalInputProducesIdenticalHashes() {
        let md = "# Hello\n\nWorld\n\n```swift\nlet x = 1\n```\n"
        let a = ChatMarkdownDocument(markdown: md).blocks.map(\.contentHash)
        let b = ChatMarkdownDocument(markdown: md).blocks.map(\.contentHash)
        XCTAssertEqual(a, b)
    }

    func testEditingTrailingBlockLeavesPrefixHashesStable() {
        let original = "# Title\n\nIntro paragraph.\n\nMore text."
        let edited   = "# Title\n\nIntro paragraph.\n\nMore text and an edit."

        let a = ChatMarkdownDocument(markdown: original).blocks.map(\.contentHash)
        let b = ChatMarkdownDocument(markdown: edited).blocks.map(\.contentHash)

        XCTAssertEqual(a.count, b.count)
        XCTAssertEqual(a[0], b[0], "heading hash should be stable")
        XCTAssertEqual(a[1], b[1], "intro paragraph hash should be stable")
        XCTAssertNotEqual(a[2], b[2], "trailing edited paragraph hash should differ")
    }

    func testHashesAreNonZero() {
        // Sanity — FNV-1a never produces 0 for non-empty inputs we care about.
        let blocks = ChatMarkdownDocument(markdown: "# A\n\nB").blocks
        XCTAssertFalse(blocks.isEmpty)
        for b in blocks {
            XCTAssertNotEqual(b.contentHash, 0)
        }
    }

    func testDifferentContentHashesDiffer() {
        let h1 = ChatMarkdownDocument(markdown: "alpha").blocks[0].contentHash
        let h2 = ChatMarkdownDocument(markdown: "beta").blocks[0].contentHash
        XCTAssertNotEqual(h1, h2)
    }

    func testCodeBlockHashSensitiveToLanguage() {
        let h1 = ChatMarkdownDocument(markdown: "```swift\nx\n```").blocks[0].contentHash
        let h2 = ChatMarkdownDocument(markdown: "```python\nx\n```").blocks[0].contentHash
        XCTAssertNotEqual(h1, h2)
    }
}
