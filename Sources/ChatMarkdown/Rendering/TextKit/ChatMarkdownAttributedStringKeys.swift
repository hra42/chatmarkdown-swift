import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

extension NSAttributedString.Key {
    static let chatMarkdownBlockID = NSAttributedString.Key("chatMarkdown.blockID")
    static let chatMarkdownBlockKind = NSAttributedString.Key("chatMarkdown.blockKind")
    static let chatMarkdownAttachmentSlot = NSAttributedString.Key("chatMarkdown.attachmentSlot")
    static let chatMarkdownBlockquoteRule = NSAttributedString.Key("chatMarkdown.blockquoteRule")
    static let chatMarkdownHorizontalRule = NSAttributedString.Key("chatMarkdown.horizontalRule")
    static let chatMarkdownListMarker = NSAttributedString.Key("chatMarkdown.listMarker")
    static let chatMarkdownInlineCode = NSAttributedString.Key("chatMarkdown.inlineCode")
}

enum ChatMarkdownBlockKind: String, Sendable {
    case heading
    case paragraph
    case codeBlock
    case unorderedList
    case orderedList
    case blockquote
    case table
    case horizontalRule
}

enum ChatMarkdownAttachmentSlotKind: String, Sendable {
    case codeBlock
    case table
}

enum ChatMarkdownAttachmentSlotPayload: Sendable, Hashable {
    case codeBlock(language: String?, code: String, isClosed: Bool)
    case table(headers: [[ChatMarkdownInline]], rows: [[[ChatMarkdownInline]]], alignments: [TableAlignment])

    var kind: ChatMarkdownAttachmentSlotKind {
        switch self {
        case .codeBlock: return .codeBlock
        case .table: return .table
        }
    }
}

// NSAttributedString attribute values must be reference types or property-list types.
// Box value-typed payloads in an NSObject so they survive the Foundation bridge.
final class ChatMarkdownAttachmentSlotBox: NSObject {
    let payload: ChatMarkdownAttachmentSlotPayload

    init(_ payload: ChatMarkdownAttachmentSlotPayload) {
        self.payload = payload
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ChatMarkdownAttachmentSlotBox else { return false }
        return other.payload == payload
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(payload)
        return hasher.finalize()
    }
}

#endif
