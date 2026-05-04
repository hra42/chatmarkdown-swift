import XCTest
@testable import ChatMarkdown

final class SyntaxHighlighterTests: XCTestCase {
    private func classes(_ tokens: [(NSRange, TokenClass)]) -> Set<TokenClass> {
        Set(tokens.map { $0.1 })
    }

    func testSwiftKeywordAndType() {
        let code = "let x: Int = 5"
        let tokens = SyntaxHighlighter.tokenize(code, language: "swift")
        XCTAssertTrue(classes(tokens).contains(.keyword))
        XCTAssertTrue(classes(tokens).contains(.type))
        XCTAssertTrue(classes(tokens).contains(.number))
    }

    func testSwiftStringNotKeywordHighlighted() {
        // First-match-wins: keyword "let" inside a string must NOT be classified as keyword
        let code = "\"let x\""
        let tokens = SyntaxHighlighter.tokenize(code, language: "swift")
        // The whole code is one string token
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens.first?.1, .string)
    }

    func testSwiftLineComment() {
        let code = "// comment with let inside"
        let tokens = SyntaxHighlighter.tokenize(code, language: "swift")
        XCTAssertEqual(tokens.first?.1, .comment)
    }

    func testPythonComment() {
        let tokens = SyntaxHighlighter.tokenize("# hello", language: "python")
        XCTAssertEqual(tokens.first?.1, .comment)
    }

    func testJSONNumberAndKeyword() {
        let tokens = SyntaxHighlighter.tokenize("{\"a\": 1, \"b\": true}", language: "json")
        let cls = classes(tokens)
        XCTAssertTrue(cls.contains(.string))
        XCTAssertTrue(cls.contains(.number))
        XCTAssertTrue(cls.contains(.keyword))
    }

    func testGenericFallbackForUnknownLanguage() {
        let tokens = SyntaxHighlighter.tokenize("123 \"abc\"", language: "ocaml")
        let cls = classes(tokens)
        XCTAssertTrue(cls.contains(.number))
        XCTAssertTrue(cls.contains(.string))
    }

    func testEmptyInput() {
        let tokens = SyntaxHighlighter.tokenize("", language: "swift")
        XCTAssertTrue(tokens.isEmpty)
    }
}
