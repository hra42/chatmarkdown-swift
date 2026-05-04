#if canImport(AppKit) || canImport(UIKit)

import Foundation
import XCTest
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Edge cases called out by the dev-plan Phase 5: documents the renderer
/// must handle without crashing or losing fidelity.
final class TextKitEdgeCaseTests: XCTestCase {

    private let theme = ChatMarkdownTheme()

    // MARK: - Empty

    func testEmptyDocumentBuildsEmptyStorageAndAppliesCleanly() {
        let document = ChatMarkdownDocument(markdown: "")
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: theme)

        XCTAssertEqual(result.attributed.length, 0)
        XCTAssertTrue(result.blockRanges.isEmpty)
        XCTAssertTrue(result.blockIDs.isEmpty)

        // applying to a host view must not crash
        let view = makeView()
        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        XCTAssertEqual(storageLength(of: view), 0)
    }

    // MARK: - Single-block documents

    func testSingleCodeBlockOnlyEmitsOneAttachmentSlot() {
        let markdown = "```swift\nlet x = 1\n```"
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        let slots = collectSlots(in: attributed)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].kind, .codeBlock)
        XCTAssertTrue(attributed.string.contains("let x = 1"),
                      "Code body must remain in storage as selectable text")
    }

    func testSingleTableOnlyEmitsOneAttachmentSlot() {
        let markdown = """
        | A | B |
        | - | - |
        | 1 | 2 |
        """
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        let slots = collectSlots(in: attributed)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].kind, .table)
    }

    // MARK: - Long code line

    func testLongCodeLinePreservedInStorage() {
        let longLine = String(repeating: "abcdef ", count: 40) // ~280 chars
        let markdown = "```\n\(longLine)\n```"
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        XCTAssertTrue(attributed.string.contains(longLine),
                      "Long code line must round-trip into storage unmodified")
    }

    // MARK: - Right-to-left

    func testRTLParagraphUsesNaturalWritingDirection() {
        // Arabic: "Hello, world."
        let markdown = "مرحبا، يا عالم."
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)

        XCTAssertGreaterThan(attributed.length, 0)
        let style = attributed.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle
        XCTAssertNotNil(style)
        // .natural lets the bidi algorithm derive direction from the leading
        // strong-direction character — which is what we want for mixed
        // RTL/LTR chat content.
        XCTAssertEqual(style?.baseWritingDirection, .natural,
                       "Builder must not hardcode LTR for paragraphs")
    }

    // MARK: - Dynamic Type (iOS only)

    #if canImport(UIKit)
    func testBodyFontTracksDynamicType() {
        let font = TextKitThemeAdapter.bodyFont(for: theme)
        // UIFont.preferredFont(forTextStyle:) returns a font whose
        // descriptor declares the .body text style — this is the contract
        // that lets Dynamic Type scale the font when the user changes their
        // preferred content size.
        let style = font.fontDescriptor.object(forKey: .textStyle) as? String
        XCTAssertEqual(
            style, UIFont.TextStyle.body.rawValue,
            "Body font must declare the .body text style so it scales with Dynamic Type"
        )
    }
    #endif

    // MARK: - Helpers

    private struct SlotHit {
        let range: NSRange
        let kind: ChatMarkdownAttachmentSlotKind
    }

    private func collectSlots(in s: NSAttributedString) -> [SlotHit] {
        var hits: [SlotHit] = []
        s.enumerateAttribute(
            .chatMarkdownAttachmentSlot,
            in: NSRange(location: 0, length: s.length),
            options: []
        ) { value, range, _ in
            guard let box = value as? ChatMarkdownAttachmentSlotBox else { return }
            hits.append(SlotHit(range: range, kind: box.payload.kind))
        }
        return hits
    }

    #if canImport(AppKit)
    private func makeView() -> ChatMarkdownNSTextView {
        let view = ChatMarkdownNSTextView(frame: .zero)
        view.isEditable = false
        view.isSelectable = true
        return view
    }

    private func storageLength(of view: ChatMarkdownNSTextView) -> Int {
        view.textStorage?.length ?? -1
    }
    #else
    private func makeView() -> ChatMarkdownUITextView {
        let view = ChatMarkdownUITextView(frame: .zero, textContainer: nil)
        view.isEditable = false
        view.isSelectable = true
        return view
    }

    private func storageLength(of view: ChatMarkdownUITextView) -> Int {
        view.textStorage.length
    }
    #endif
}

#endif
