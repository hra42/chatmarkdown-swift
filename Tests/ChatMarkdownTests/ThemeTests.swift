import XCTest
import SwiftUI
@testable import ChatMarkdown

final class ThemeTests: XCTestCase {
    func testForRoleReturnsRoleSpecificThemes() {
        // .user theme has white text; .assistant uses .primary. They are not equal byte-for-byte
        // but we can compare a discriminating field.
        let user = ChatMarkdownTheme.forRole(.user)
        let assistant = ChatMarkdownTheme.forRole(.assistant)
        XCTAssertNotEqual(user.textColor, assistant.textColor)
    }

    func testPDFLightUsesBlackText() {
        XCTAssertEqual(ChatMarkdownTheme.pdfLight.textColor, .black)
    }

    func testDefaultThemeHasAllSixHeadingLevels() {
        let theme = ChatMarkdownTheme()
        for level in 1...6 {
            XCTAssertNotNil(theme.headingFonts[level], "missing heading font for level \(level)")
        }
    }

    func testThemeIsMutable() {
        var theme = ChatMarkdownTheme.assistant
        theme.linkColor = .red
        XCTAssertEqual(theme.linkColor, .red)
        // Original preset unchanged
        XCTAssertNotEqual(ChatMarkdownTheme.assistant.linkColor, .red)
    }
}
