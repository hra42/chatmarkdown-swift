import Foundation
import SwiftUI

/// Renders a `ChatMarkdownDocument` to either a Foundation `AttributedString`
/// (carrying SwiftUI `Font` / `Color` attributes — suitable for `Text(_:)`
/// and `ImageRenderer`) or a platform `NSAttributedString` (suitable for
/// `NSPasteboard` / RTF round-trips).
public enum ChatMarkdownAttributedRenderer {
    public static func render(
        _ markdown: String,
        theme: ChatMarkdownTheme = ChatMarkdownTheme()
    ) -> AttributedString {
        render(document: ChatMarkdownDocument(markdown: markdown), theme: theme)
    }

    public static func render(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme = ChatMarkdownTheme()
    ) -> AttributedString {
        BlockToAttributed.render(blocks: document.blocks, theme: theme)
    }

    public static func renderNS(
        _ markdown: String,
        theme: ChatMarkdownTheme = ChatMarkdownTheme()
    ) -> NSAttributedString {
        renderNS(document: ChatMarkdownDocument(markdown: markdown), theme: theme)
    }

    public static func renderNS(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme = ChatMarkdownTheme()
    ) -> NSAttributedString {
        BlockToAttributed.renderNS(blocks: document.blocks, theme: theme)
    }
}
