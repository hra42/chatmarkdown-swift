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

        // Table slot range must include reserved newlines (header + 2 rows = 3) plus the slot character = 4.
        if case .table(_, let rows, _) = slots[1].payload {
            XCTAssertEqual(slots[1].range.length, 1 + 1 + rows.count)
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
