#if canImport(AppKit) || canImport(UIKit)

import SwiftUI
import XCTest
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class TextKitHostTests: XCTestCase {

    // MARK: - Host construction

    func testHostBuildsTextViewWithSelectableNonEditableContent() throws {
        let markdown = try FixtureSupport.loadInput("mixed-llm-response")
        let document = ChatMarkdownDocument(markdown: markdown)
        let theme = ChatMarkdownTheme()
        let host = ChatMarkdownTextKitHost(document: document, theme: theme)

        let view = makeViewWithoutSwiftUIContext(host: host, document: document, theme: theme)

        #if canImport(AppKit)
        XCTAssertFalse(view.isEditable)
        XCTAssertTrue(view.isSelectable)
        XCTAssertNotNil(view.textStorage)
        XCTAssertGreaterThan(view.textStorage?.length ?? 0, 0)
        #else
        XCTAssertFalse(view.isEditable)
        XCTAssertTrue(view.isSelectable)
        XCTAssertGreaterThan(view.textStorage.length, 0)
        XCTAssertFalse(view.isScrollEnabled)
        #endif
    }

    func testApplyReplacesStorageOnSubsequentDocument() throws {
        let theme = ChatMarkdownTheme()
        let docA = ChatMarkdownDocument(markdown: "# Heading A\n\nFirst paragraph.")
        let docB = ChatMarkdownDocument(markdown: "# Heading B\n\nSecond paragraph with more words.")

        let hostA = ChatMarkdownTextKitHost(document: docA, theme: theme)
        let view = makeViewWithoutSwiftUIContext(host: hostA, document: docA, theme: theme)

        let storageString: () -> String = {
            #if canImport(AppKit)
            return view.textStorage?.string ?? ""
            #else
            return view.textStorage.string
            #endif
        }

        XCTAssertTrue(storageString().contains("Heading A"))
        XCTAssertTrue(storageString().contains("First paragraph"))

        ChatMarkdownTextKitHost.apply(document: docB, theme: theme, to: view)

        XCTAssertTrue(storageString().contains("Heading B"))
        XCTAssertTrue(storageString().contains("Second paragraph"))
        XCTAssertFalse(storageString().contains("Heading A"))
    }

    // MARK: - Modifier propagation

    func testRendererModifierSetsEnvironmentValue() {
        var env = EnvironmentValues()
        XCTAssertEqual(env.chatMarkdownRendererKind, .textKit)
        env.chatMarkdownRendererKind = .swiftUI
        XCTAssertEqual(env.chatMarkdownRendererKind, .swiftUI)
    }

    // MARK: - Helpers

    /// Bypasses SwiftUI by directly calling the same configuration path used by makeNSView/makeUIView.
    /// We can't easily synthesize a SwiftUI Context, so we replicate the configuration the host applies.
    private func makeViewWithoutSwiftUIContext(
        host: ChatMarkdownTextKitHost,
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme
    ) -> ChatMarkdownPlatformTextView {
        #if canImport(AppKit)
        let view = ChatMarkdownNSTextView(frame: .zero)
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.isAutomaticLinkDetectionEnabled = true
        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        return view
        #else
        let view = ChatMarkdownUITextView(frame: .zero, textContainer: nil)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)
        return view
        #endif
    }
}

#if canImport(AppKit)
private typealias ChatMarkdownPlatformTextView = ChatMarkdownNSTextView
#else
private typealias ChatMarkdownPlatformTextView = ChatMarkdownUITextView
#endif

#endif
