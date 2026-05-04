#if canImport(AppKit) || canImport(UIKit)

import XCTest
import SwiftUI
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class TextKitThemeFontTests: XCTestCase {

    // MARK: - bodyFont

    func testCustomBodyFontSizeFlowsThroughTextKit() {
        var theme = ChatMarkdownTheme()
        theme.bodyFont = .system(size: 22)

        let document = ChatMarkdownDocument(markdown: "Hello world")
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        let font = firstFont(in: attributed)
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize ?? 0, 22, accuracy: 0.5)
    }

    // MARK: - headingFonts

    func testCustomHeadingFontSizeAndBoldFlowsThroughTextKit() {
        var theme = ChatMarkdownTheme()
        theme.headingFonts[1] = .system(size: 40, weight: .bold)

        let document = ChatMarkdownDocument(markdown: "# Title")
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        let font = firstFont(in: attributed)
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize ?? 0, 40, accuracy: 0.5)
        XCTAssertTrue(isBold(font), "Expected H1 font to be bold")
    }

    // MARK: - codeFont (.custom)

    func testCustomCodeFontFlowsThroughTextKit() {
        var theme = ChatMarkdownTheme()
        theme.codeFont = .custom("Courier", size: 18)

        let document = ChatMarkdownDocument(markdown: "```\nlet x = 1\n```")
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        // Find the code-body run (skip the attachment slot at offset 0).
        guard let font = firstNonAttachmentFont(in: attributed) else {
            return XCTFail("No code body font run found")
        }
        XCTAssertEqual(font.pointSize, 18, accuracy: 0.5)
        // Font name may resolve to "Courier" or fall back to system; size is the firm guarantee.
    }

    // MARK: - inlineCodeFont

    func testCustomInlineCodeFontFlowsThroughTextKit() {
        var theme = ChatMarkdownTheme()
        theme.inlineCodeFont = .system(size: 19, design: .monospaced)

        let document = ChatMarkdownDocument(markdown: "use `frobnicate` here")
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        guard let font = inlineCodeFont(in: attributed) else {
            return XCTFail("No inline code run found")
        }
        XCTAssertEqual(font.pointSize, 19, accuracy: 0.5)
        XCTAssertTrue(isMonospaced(font), "Expected inline code font to be monospaced")
    }

    // MARK: - BlockToAttributed.renderNS()

    func testCustomBodyFontFlowsThroughRenderNS() {
        var theme = ChatMarkdownTheme()
        theme.bodyFont = .system(size: 24)

        let document = ChatMarkdownDocument(markdown: "Hello world")
        let attributed = BlockToAttributed.renderNS(blocks: document.blocks, theme: theme)

        let font = firstFont(in: attributed)
        XCTAssertNotNil(font)
        XCTAssertEqual(font?.pointSize ?? 0, 24, accuracy: 0.5)
    }

    // MARK: - Helpers

    private func firstFont(in attributed: NSAttributedString) -> PlatformFont? {
        guard attributed.length > 0 else { return nil }
        var idx = 0
        while idx < attributed.length {
            let attrs = attributed.attributes(at: idx, effectiveRange: nil)
            if let f = attrs[.font] as? PlatformFont,
               attributed.string.unicodeScalars[
                   attributed.string.unicodeScalars.index(
                       attributed.string.unicodeScalars.startIndex, offsetBy: idx
                   )
               ] != "\u{FFFC}" {
                return f
            }
            idx += 1
        }
        return attributed.attribute(.font, at: 0, effectiveRange: nil) as? PlatformFont
    }

    private func firstNonAttachmentFont(in attributed: NSAttributedString) -> PlatformFont? {
        let scalars = Array(attributed.string.unicodeScalars)
        for idx in 0..<attributed.length {
            guard idx < scalars.count else { break }
            if scalars[idx] == "\u{FFFC}" { continue }
            if let f = attributed.attribute(.font, at: idx, effectiveRange: nil) as? PlatformFont {
                return f
            }
        }
        return nil
    }

    private func inlineCodeFont(in attributed: NSAttributedString) -> PlatformFont? {
        var found: PlatformFont?
        attributed.enumerateAttribute(
            .chatMarkdownInlineCode,
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { value, range, stop in
            guard (value as? Bool) == true else { return }
            found = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? PlatformFont
            stop.pointee = true
        }
        return found
    }

    private func isBold(_ font: PlatformFont?) -> Bool {
        guard let font else { return false }
        #if canImport(AppKit)
        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
        #else
        return font.fontDescriptor.symbolicTraits.contains(.traitBold)
        #endif
    }

    private func isMonospaced(_ font: PlatformFont) -> Bool {
        #if canImport(AppKit)
        if font.isFixedPitch { return true }
        return font.fontName.lowercased().contains("mono")
            || font.fontName.lowercased().contains("menlo")
            || font.fontName.lowercased().contains("courier")
        #else
        if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) { return true }
        return font.fontName.lowercased().contains("mono")
            || font.fontName.lowercased().contains("menlo")
            || font.fontName.lowercased().contains("courier")
        #endif
    }
}

#endif
