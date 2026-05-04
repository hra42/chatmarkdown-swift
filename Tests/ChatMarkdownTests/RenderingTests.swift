import XCTest
import SwiftUI
@testable import ChatMarkdown

@MainActor
final class RenderingTests: XCTestCase {
    /// Force a SwiftUI view tree to actually evaluate `body`. We don't compare pixels;
    /// we just want to confirm that constructing and rendering each block kind doesn't crash.
    private func smokeRender<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view.frame(width: 600, height: 400))
        // Touch cgImage to force evaluation. Image may be nil on some platforms; that's fine.
        _ = renderer.cgImage
    }

    func testRendersHeading() {
        smokeRender(ChatMarkdownView("# Title"))
    }

    func testRendersParagraphWithInlines() {
        smokeRender(ChatMarkdownView("Plain **bold** *italic* `code` [link](https://x).\n"))
    }

    func testRendersCodeBlock() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        smokeRender(ChatMarkdownView(md))
    }

    func testRendersUnclosedCodeBlock() {
        let md = "```swift\nlet x = 1"
        smokeRender(ChatMarkdownView(md))
    }

    func testRendersUnorderedList() {
        smokeRender(ChatMarkdownView("- one\n- two\n  - nested\n"))
    }

    func testRendersOrderedList() {
        smokeRender(ChatMarkdownView("1. one\n2. two\n"))
    }

    func testRendersBlockquote() {
        smokeRender(ChatMarkdownView("> quote\n> line two\n"))
    }

    func testRendersTable() {
        let md = """
        | a | b |
        | - | - |
        | 1 | 2 |
        """
        smokeRender(ChatMarkdownView(md))
    }

    func testRendersHorizontalRule() {
        smokeRender(ChatMarkdownView("before\n\n---\n\nafter\n"))
    }

    func testRendersEmptyDocument() {
        smokeRender(ChatMarkdownView(""))
    }

    func testRendersWithUserRole() {
        smokeRender(ChatMarkdownView("hello", role: .user))
    }

    func testRendersWithThemeOverride() {
        smokeRender(ChatMarkdownView("hello").chatMarkdownTheme(.pdfLight))
    }

    func testRendersWithCustomCodeBlockStyle() {
        struct PlainStyle: ChatMarkdownCodeBlockStyle {
            func makeBody(configuration: ChatMarkdownCodeBlockConfiguration) -> some View {
                Text(configuration.code)
            }
        }
        smokeRender(
            ChatMarkdownView("```\nhello\n```")
                .chatMarkdownCodeBlockStyle(PlainStyle())
        )
    }
}
