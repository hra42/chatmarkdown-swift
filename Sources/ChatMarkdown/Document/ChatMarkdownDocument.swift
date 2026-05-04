import Foundation
import Markdown

public struct ChatMarkdownDocument: Hashable, Sendable, Codable {
    public let blocks: [ChatMarkdownBlock]

    public init(markdown: String) {
        let doc = Markdown.Document(parsing: markdown)
        self.blocks = MarkupNormalizer.blocks(from: doc, source: markdown)
    }

    public init(blocks: [ChatMarkdownBlock]) {
        self.blocks = blocks
    }
}
