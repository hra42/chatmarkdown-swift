import SwiftUI

public struct ChatMarkdownView: View {
    private let document: ChatMarkdownDocument
    private let role: MessageRole

    @Environment(\.chatMarkdownThemeOverride) private var themeOverride

    public init(_ markdown: String, role: MessageRole = .assistant) {
        self.document = ChatMarkdownDocument(markdown: markdown)
        self.role = role
    }

    public init(_ document: ChatMarkdownDocument, role: MessageRole = .assistant) {
        self.document = document
        self.role = role
    }

    public var body: some View {
        let theme = themeOverride ?? .forRole(role)
        BlockListView(blocks: document.blocks, theme: theme)
            .foregroundStyle(theme.textColor)
            .tint(theme.linkColor)
    }
}
