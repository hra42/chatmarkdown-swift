import XCTest
import SwiftUI
@testable import ChatMarkdown

final class InlineAttributedStringTests: XCTestCase {
    func testPlainText() {
        let result = InlineAttributedStringBuilder.build(
            [.text("hello")],
            theme: .assistant,
            baseFont: .body
        )
        XCTAssertEqual(String(result.characters), "hello")
    }

    func testBoldItalicNested() {
        let result = InlineAttributedStringBuilder.build(
            [.bold([.italic([.text("x")])])],
            theme: .assistant,
            baseFont: .body
        )
        XCTAssertEqual(String(result.characters), "x")
        // At least one run with a non-nil font
        var sawFont = false
        for run in result.runs {
            if run.font != nil { sawFont = true }
        }
        XCTAssertTrue(sawFont)
    }

    func testInlineCode() {
        let result = InlineAttributedStringBuilder.build(
            [.text("a "), .code("x()"), .text(" b")],
            theme: .assistant,
            baseFont: .body
        )
        XCTAssertEqual(String(result.characters), "a x() b")
        // The code segment should have a non-nil background color
        var sawBackground = false
        for run in result.runs {
            if run.backgroundColor != nil { sawBackground = true }
        }
        XCTAssertTrue(sawBackground)
    }

    func testLink() {
        let result = InlineAttributedStringBuilder.build(
            [.link(text: [.text("click")], url: "https://example.com")],
            theme: .assistant,
            baseFont: .body
        )
        XCTAssertEqual(String(result.characters), "click")
        var foundLink: URL?
        for run in result.runs {
            if let l = run.link { foundLink = l }
        }
        XCTAssertEqual(foundLink, URL(string: "https://example.com"))
    }

    func testLineBreakAppendsNewline() {
        let result = InlineAttributedStringBuilder.build(
            [.text("a"), .lineBreak, .text("b")],
            theme: .assistant,
            baseFont: .body
        )
        XCTAssertEqual(String(result.characters), "a\nb")
    }
}
