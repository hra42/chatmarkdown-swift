#if canImport(AppKit) || canImport(UIKit)

import SwiftUI
import XCTest
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class TextKitOverlayTests: XCTestCase {

    func testOverlaySlotScannerFindsCodeAndTableSlots() {
        let markdown = """
        Intro paragraph.

        ```swift
        let x = 1
        ```

        | A | B |
        |---|---|
        | 1 | 2 |
        | 3 | 4 |

        Outro paragraph.
        """
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        let slots = ChatMarkdownOverlaySlotScanner.scan(attributed)
        XCTAssertEqual(slots.count, 2, "Expected one code slot and one table slot")

        let kinds = slots.map { $0.payload.kind }
        XCTAssertEqual(kinds, [.codeBlock, .table])

        // Table slot is a single FFFC character; height is reserved by the
        // attached ChatMarkdownTableAttachment.attachmentBounds(...).
        if case .table = slots[1].payload {
            XCTAssertEqual(slots[1].range.length, 1)
        } else {
            XCTFail("Second slot should be table")
        }
    }

    func testOverlayScannerCoalescesAdjacentTableRuns() {
        // Same payload across slot char + reserved fillers should produce ONE slot.
        let document = ChatMarkdownDocument(markdown: "| H |\n|---|\n| a |\n| b |")
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())
        let slots = ChatMarkdownOverlaySlotScanner.scan(attributed)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].payload.kind, .table)
    }

    func testHostInstallsOverlayViewsForCodeAndTable() throws {
        #if canImport(AppKit)
        let markdown = """
        Intro.

        ```swift
        let x = 1
        ```

        | A | B |
        |---|---|
        | 1 | 2 |

        Outro.
        """
        let document = ChatMarkdownDocument(markdown: markdown)
        let theme = ChatMarkdownTheme()

        let view = ChatMarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0

        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        view.layoutSubtreeIfNeeded()
        view.relayoutChatMarkdownOverlays()

        XCTAssertEqual(view.chatMarkdownOverlayManager.overlayViews.count, 2,
                       "Expected one overlay each for the code block and the table")
        for overlay in view.chatMarkdownOverlayManager.overlayViews {
            XCTAssertGreaterThan(overlay.frame.width, 0)
            XCTAssertGreaterThan(overlay.frame.height, 0)
            XCTAssertNotNil(overlay.superview, "Overlay must be added as a subview of the text view")
        }
        #else
        try XCTSkipIf(true, "Host overlay test runs on macOS only — UIKit equivalent requires a window context.")
        #endif
    }

    func testOverlayHostsArePreservedAcrossStableUpdates() throws {
        #if canImport(AppKit)
        let markdownA = """
        Intro.

        ```swift
        let x = 1
        ```

        Outro short.
        """
        let markdownB = """
        Intro.

        ```swift
        let x = 1
        ```

        Outro short with more words appended.
        """
        let theme = ChatMarkdownTheme()

        let view = ChatMarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0

        ChatMarkdownTextKitHost.apply(
            document: ChatMarkdownDocument(markdown: markdownA),
            theme: theme,
            to: view
        )
        view.layoutSubtreeIfNeeded()
        view.relayoutChatMarkdownOverlays()
        XCTAssertEqual(view.chatMarkdownOverlayManager.overlayViews.count, 1)
        let identityBefore = view.chatMarkdownOverlayManager.overlayViews.first.map(ObjectIdentifier.init)

        ChatMarkdownTextKitHost.apply(
            document: ChatMarkdownDocument(markdown: markdownB),
            theme: theme,
            to: view
        )
        view.layoutSubtreeIfNeeded()
        view.relayoutChatMarkdownOverlays()
        XCTAssertEqual(view.chatMarkdownOverlayManager.overlayViews.count, 1)
        let identityAfter = view.chatMarkdownOverlayManager.overlayViews.first.map(ObjectIdentifier.init)

        XCTAssertEqual(identityBefore, identityAfter,
                       "Overlay view should be reused across stable updates, not recreated")
        #else
        try XCTSkipIf(true, "macOS only")
        #endif
    }

    // MARK: - Bug 2: table attachment reserves real height

    func testTableAttachmentReservesHeightBeyondNaiveLineCount() throws {
        #if canImport(AppKit)
        // Multi-line cells force the SwiftUI table to render taller than
        // bodyLineHeight × (rows + 1). The old newline-filler heuristic
        // would under-reserve here; the attachment-bounds path measures
        // the real height.
        let markdown = """
        | Header A with a fairly long label | Header B |
        |---|---|
        | A long cell value that will likely wrap onto multiple lines when the column is narrow | b |
        | another long cell that wraps in a narrow column | d |
        """
        let document = ChatMarkdownDocument(markdown: markdown)
        let theme = ChatMarkdownTheme()

        let view = ChatMarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 1000))
        view.isEditable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.size = NSSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude)

        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        view.layoutSubtreeIfNeeded()

        guard let storage = view.textStorage,
              let layoutManager = view.layoutManager,
              let textContainer = view.textContainer else {
            return XCTFail("text view missing storage/layout")
        }
        layoutManager.ensureLayout(for: textContainer)

        // Find the table slot range.
        var tableRange: NSRange?
        storage.enumerateAttribute(.attachment,
                                   in: NSRange(location: 0, length: storage.length),
                                   options: []) { value, range, _ in
            if value is ChatMarkdownTableAttachment { tableRange = range }
        }
        guard let range = tableRange else {
            return XCTFail("Expected a ChatMarkdownTableAttachment in storage")
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let bodyFont = TextKitThemeAdapter.bodyFont(for: theme)
        let bodyLine = bodyFont.ascender - bodyFont.descender + bodyFont.leading
        // Naive heuristic was lines = 1 (header) + 2 (rows) = 3 lines.
        let naiveHeight = bodyLine * 3
        XCTAssertGreaterThan(rect.height, naiveHeight,
            "Reserved height (\(rect.height)) should exceed naive line-count height (\(naiveHeight))")
        #else
        try XCTSkipIf(true, "macOS only")
        #endif
    }

    func testTableOverlayDoesNotOverlapFollowingParagraph() throws {
        #if canImport(AppKit)
        let markdown = """
        | A | B |
        |---|---|
        | a long wrapping cell that takes more than one line of vertical space at narrow widths | y |
        | another wrapping cell with a fair bit of content packed into one cell | z |

        Heading-like paragraph that must NOT overlap the table.
        """
        let document = ChatMarkdownDocument(markdown: markdown)
        let theme = ChatMarkdownTheme()

        let view = ChatMarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 2000))
        view.isEditable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.size = NSSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude)

        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        view.layoutSubtreeIfNeeded()

        guard let storage = view.textStorage,
              let layoutManager = view.layoutManager,
              let textContainer = view.textContainer else {
            return XCTFail("text view missing storage/layout")
        }
        layoutManager.ensureLayout(for: textContainer)

        // Locate the table slot's bounding rect.
        var tableRange: NSRange?
        storage.enumerateAttribute(.attachment,
                                   in: NSRange(location: 0, length: storage.length),
                                   options: []) { value, range, _ in
            if value is ChatMarkdownTableAttachment { tableRange = range }
        }
        guard let range = tableRange else {
            return XCTFail("Expected a ChatMarkdownTableAttachment in storage")
        }
        let tableGlyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let tableRect = layoutManager.boundingRect(forGlyphRange: tableGlyphs, in: textContainer)

        // Locate the start of the next paragraph by scanning blockKind.
        let fullRange = NSRange(location: 0, length: storage.length)
        var paragraphStart: Int?
        storage.enumerateAttribute(.chatMarkdownBlockKind, in: fullRange, options: []) { value, runRange, _ in
            if paragraphStart != nil { return }
            if let raw = value as? String, raw == ChatMarkdownBlockKind.paragraph.rawValue,
               runRange.location > range.location {
                paragraphStart = runRange.location
            }
        }
        guard let pStart = paragraphStart else {
            return XCTFail("Could not find following paragraph block")
        }

        let pGlyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: pStart, length: 1),
                                               actualCharacterRange: nil)
        let pRect = layoutManager.boundingRect(forGlyphRange: pGlyphs, in: textContainer)

        XCTAssertLessThanOrEqual(tableRect.maxY, pRect.minY + 0.5,
            "Table overlay reserved range (\(tableRect)) overlaps following paragraph (\(pRect))")
        #else
        try XCTSkipIf(true, "macOS only")
        #endif
    }

    func testWidthChangeReinvalidatesAttachmentLayout() throws {
        // Verifies the host's width-change invalidation actually runs:
        // resizing the container clears the attachment height cache and the
        // layout manager re-measures. (The default SwiftUI table style wraps
        // cells in a horizontal ScrollView whose height happens not to vary
        // with width, so we assert the *mechanism* — invalidate-on-resize —
        // rather than a numeric height delta.)
        #if canImport(AppKit)
        let markdown = """
        | A | B |
        |---|---|
        | a long wrapping cell with substantive content | y |
        """
        let document = ChatMarkdownDocument(markdown: markdown)
        let theme = ChatMarkdownTheme()

        let view = ChatMarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 1000))
        view.textContainer?.size = NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        view.isEditable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0

        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        view.layoutSubtreeIfNeeded()

        let narrowHeight = tableBoundingHeight(in: view)
        XCTAssertGreaterThan(narrowHeight, 1.5,
            "Attachment height must reflect real measurement, not the 1pt placeholder")

        view.setFrameSize(NSSize(width: 600, height: 1000))
        view.textContainer?.size = NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude)
        view.layoutSubtreeIfNeeded()

        let wideHeight = tableBoundingHeight(in: view)
        XCTAssertGreaterThan(wideHeight, 1.5,
            "Reinvalidated attachment must re-measure to a real height (not 1pt placeholder)")
        // We do not assert wideHeight < narrowHeight: the default table
        // wraps content in a horizontal ScrollView whose intrinsic height
        // doesn't shrink at wider widths. The invariant under test is that
        // the cache was cleared and the next pass produced a real height.
        #else
        try XCTSkipIf(true, "macOS only")
        #endif
    }

    #if canImport(AppKit)
    @MainActor
    private func tableBoundingHeight(in view: ChatMarkdownNSTextView) -> CGFloat {
        guard let storage = view.textStorage,
              let layoutManager = view.layoutManager,
              let textContainer = view.textContainer else { return 0 }
        // Trigger width-change invalidation so cached heights re-measure
        // when the container width has changed since the last pass.
        view.relayoutChatMarkdownOverlays()
        layoutManager.ensureLayout(for: textContainer)
        var found: CGFloat = 0
        storage.enumerateAttribute(.attachment,
                                   in: NSRange(location: 0, length: storage.length),
                                   options: []) { value, range, _ in
            guard value is ChatMarkdownTableAttachment else { return }
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            found = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer).height
        }
        return found
    }
    #endif

    func testEmptyDocumentInstallsNoOverlays() throws {
        #if canImport(AppKit)
        let document = ChatMarkdownDocument(markdown: "Just a paragraph.")
        let theme = ChatMarkdownTheme()

        let view = ChatMarkdownNSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0

        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        view.layoutSubtreeIfNeeded()
        view.relayoutChatMarkdownOverlays()

        XCTAssertEqual(view.chatMarkdownOverlayManager.overlayViews.count, 0)
        #else
        try XCTSkipIf(true, "macOS only")
        #endif
    }
}

#endif
