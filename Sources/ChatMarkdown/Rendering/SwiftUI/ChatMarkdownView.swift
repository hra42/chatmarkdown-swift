import SwiftUI

public struct ChatMarkdownView: View {
    private let document: ChatMarkdownDocument
    private let role: MessageRole

    @Environment(\.chatMarkdownThemeOverride) private var themeOverride
    @Environment(\.chatMarkdownRendererKind) private var rendererKind
    @Environment(\.chatMarkdownCodeBlockStyleOverride) private var codeBlockStyleOverride
    @Environment(\.chatMarkdownTableStyleOverride) private var tableStyleOverride

    /// Convenience init that parses `markdown` on every body evaluation.
    /// Suitable for static messages. Streaming callers should construct and
    /// own a `ChatMarkdownDocument`, update it per chunk, and pass it to the
    /// `(ChatMarkdownDocument, MessageRole)` init — that path preserves the
    /// per-block identities required by the prefix-stability invariant in
    /// `SPEC.md`.
    public init(_ markdown: String, role: MessageRole = .assistant) {
        self.document = ChatMarkdownDocument(markdown: markdown)
        self.role = role
    }

    /// Streaming-friendly init: identity of preceding blocks is preserved
    /// across re-renders when the caller mutates the document by appending
    /// to the last block only.
    public init(_ document: ChatMarkdownDocument, role: MessageRole = .assistant) {
        self.document = document
        self.role = role
    }

    public var body: some View {
        let theme = themeOverride ?? .forRole(role)
        Group {
            #if canImport(AppKit) || canImport(UIKit)
            if rendererKind == .textKit {
                ChatMarkdownTextKitHost(
                    document: document,
                    theme: theme,
                    codeBlockStyle: codeBlockStyleOverride,
                    tableStyle: tableStyleOverride
                )
            } else {
                BlockListView(blocks: document.blocks, theme: theme)
            }
            #else
            BlockListView(blocks: document.blocks, theme: theme)
            #endif
        }
        .foregroundStyle(theme.textColor)
        .tint(theme.linkColor)
    }
}
