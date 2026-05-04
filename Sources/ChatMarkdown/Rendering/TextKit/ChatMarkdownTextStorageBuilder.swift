import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

struct ChatMarkdownTextStorageBuildResult {
    let attributed: NSAttributedString
    /// One range per input block, in order. Covers only the block's own
    /// content — does not include the "\n\n" separator between blocks.
    let blockRanges: [NSRange]
    /// `BlockIDSequence.make(blocks)` for the same blocks, in order.
    let blockIDs: [BlockID]
}

enum ChatMarkdownTextStorageBuilder {
    static func build(document: ChatMarkdownDocument, theme: ChatMarkdownTheme) -> NSAttributedString {
        buildWithIndex(document: document, theme: theme).attributed
    }

    static func build(blocks: [ChatMarkdownBlock], theme: ChatMarkdownTheme) -> NSAttributedString {
        buildWithIndex(blocks: blocks, theme: theme).attributed
    }

    static func buildWithIndex(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme
    ) -> ChatMarkdownTextStorageBuildResult {
        buildWithIndex(blocks: document.blocks, theme: theme)
    }

    static func buildWithIndex(
        blocks: [ChatMarkdownBlock],
        theme: ChatMarkdownTheme
    ) -> ChatMarkdownTextStorageBuildResult {
        let out = NSMutableAttributedString()
        let ids = BlockIDSequence.make(blocks)
        var ranges: [NSRange] = []
        ranges.reserveCapacity(blocks.count)
        for (i, block) in blocks.enumerated() {
            let blockStart = out.length
            appendBlock(block, into: out, theme: theme, indent: 0)
            let blockRange = NSRange(location: blockStart, length: out.length - blockStart)
            stampBlockKind(block.kind, on: out, range: blockRange)
            stampBlockID(ids[i], on: out, range: blockRange)
            ranges.append(blockRange)
            if i < blocks.count - 1 {
                out.append(NSAttributedString(string: "\n\n"))
            }
        }
        return ChatMarkdownTextStorageBuildResult(
            attributed: out,
            blockRanges: ranges,
            blockIDs: ids
        )
    }

    // MARK: - Block walker

    private static func appendBlock(
        _ block: ChatMarkdownBlock,
        into out: NSMutableAttributedString,
        theme: ChatMarkdownTheme,
        indent: Int
    ) {
        switch block {
        case .heading(let level, let inlines):
            let font = TextKitThemeAdapter.headingFont(level: level, theme: theme)
            let inline = NSInlineBuilder.build(
                inlines,
                baseFont: font,
                baseColor: PlatformColors.primary,
                inlineCodeFont: TextKitThemeAdapter.inlineCodeFont(for: theme)
            )
            let styled = NSMutableAttributedString(attributedString: inline)
            applyParagraphStyle(blockSpacing: theme.blockSpacing, indent: indent, theme: theme, to: styled)
            markInlineCodeRuns(in: styled)
            out.append(styled)

        case .paragraph(let inlines):
            let font = TextKitThemeAdapter.bodyFont(for: theme)
            let inline = NSInlineBuilder.build(
                inlines,
                baseFont: font,
                baseColor: PlatformColors.primary,
                inlineCodeFont: TextKitThemeAdapter.inlineCodeFont(for: theme)
            )
            let styled = NSMutableAttributedString(attributedString: inline)
            applyParagraphStyle(blockSpacing: theme.blockSpacing, indent: indent, theme: theme, to: styled)
            markInlineCodeRuns(in: styled)
            out.append(styled)

        case .codeBlock(let language, let code, let isClosed):
            let payload = ChatMarkdownAttachmentSlotPayload.codeBlock(
                language: language,
                code: code,
                isClosed: isClosed
            )
            let slot = makeAttachmentSlot(payload: payload, theme: theme, indent: indent)
            out.append(slot)

            let mono = TextKitThemeAdapter.codeFont(for: theme)
            let bgColor = TextKitThemeAdapter.platformColor(theme.codeBackground)
            let body = NSMutableAttributedString(
                string: code,
                attributes: [
                    .font: mono,
                    .foregroundColor: PlatformColors.primary,
                    .backgroundColor: bgColor,
                ]
            )
            applyParagraphStyle(blockSpacing: theme.blockSpacing, indent: indent, theme: theme, to: body)
            out.append(body)

        case .unorderedList(let items):
            for (idx, item) in items.enumerated() {
                appendListItem(
                    marker: "•\t",
                    item: item,
                    into: out,
                    theme: theme,
                    indent: indent
                )
                if idx < items.count - 1 {
                    out.append(NSAttributedString(string: "\n"))
                }
            }

        case .orderedList(let start, let items):
            for (idx, item) in items.enumerated() {
                appendListItem(
                    marker: "\(start + idx).\t",
                    item: item,
                    into: out,
                    theme: theme,
                    indent: indent
                )
                if idx < items.count - 1 {
                    out.append(NSAttributedString(string: "\n"))
                }
            }

        case .blockquote(let blocks):
            let blockquoteStart = out.length
            for (idx, sub) in blocks.enumerated() {
                appendBlock(sub, into: out, theme: theme, indent: indent + 1)
                if idx < blocks.count - 1 {
                    out.append(NSAttributedString(string: "\n"))
                }
            }
            let blockquoteRange = NSRange(location: blockquoteStart, length: out.length - blockquoteStart)
            if blockquoteRange.length > 0 {
                out.addAttribute(.chatMarkdownBlockquoteRule, value: true, range: blockquoteRange)
            }

        case .table(let headers, let rows, let alignments):
            let payload = ChatMarkdownAttachmentSlotPayload.table(
                headers: headers,
                rows: rows,
                alignments: alignments
            )
            // Single-character slot. Vertical space is reserved by the
            // attached `ChatMarkdownTableAttachment` whose `attachmentBounds`
            // measures the SwiftUI table at the actual container width.
            let attachment = ChatMarkdownTableAttachment(
                payload: payload,
                theme: theme,
                tableStyle: AnyChatMarkdownTableStyle(DefaultChatMarkdownTableStyle())
            )
            let slot = makeAttachmentSlot(
                payload: payload,
                theme: theme,
                indent: indent,
                attachment: attachment
            )
            out.append(slot)

        case .horizontalRule:
            let rule = NSMutableAttributedString(
                string: "\n",
                attributes: [
                    .font: TextKitThemeAdapter.bodyFont(for: theme),
                    .foregroundColor: TextKitThemeAdapter.platformColor(theme.horizontalRuleColor),
                    .chatMarkdownHorizontalRule: true,
                ]
            )
            out.append(rule)
        }
    }

    private static func appendListItem(
        marker: String,
        item: [ChatMarkdownBlock],
        into out: NSMutableAttributedString,
        theme: ChatMarkdownTheme,
        indent: Int
    ) {
        let font = TextKitThemeAdapter.bodyFont(for: theme)
        let markerString = NSMutableAttributedString(
            string: marker,
            attributes: [
                .font: font,
                .foregroundColor: PlatformColors.primary,
                .chatMarkdownListMarker: true,
            ]
        )
        applyParagraphStyle(blockSpacing: 0, indent: indent + 1, theme: theme, to: markerString)
        out.append(markerString)

        for (i, sub) in item.enumerated() {
            appendBlock(sub, into: out, theme: theme, indent: indent + 1)
            if i < item.count - 1 {
                out.append(NSAttributedString(string: "\n"))
            }
        }
    }

    // MARK: - Attachment slot

    private static func makeAttachmentSlot(
        payload: ChatMarkdownAttachmentSlotPayload,
        theme: ChatMarkdownTheme,
        indent: Int,
        attachment: NSTextAttachment? = nil
    ) -> NSAttributedString {
        let box = ChatMarkdownAttachmentSlotBox(payload)
        var attributes: [NSAttributedString.Key: Any] = [
            .chatMarkdownAttachmentSlot: box,
            .font: TextKitThemeAdapter.bodyFont(for: theme),
        ]
        if let attachment {
            attributes[.attachment] = attachment
        }
        let slot = NSMutableAttributedString(
            string: "\u{FFFC}",
            attributes: attributes
        )
        applyParagraphStyle(blockSpacing: theme.blockSpacing, indent: indent, theme: theme, to: slot)
        return slot
    }

    // MARK: - Paragraph styling

    private static func applyParagraphStyle(
        blockSpacing: CGFloat,
        indent: Int,
        theme: ChatMarkdownTheme,
        to string: NSMutableAttributedString
    ) {
        guard string.length > 0 else { return }
        let style = NSMutableParagraphStyle()
        let head = theme.listIndent * CGFloat(indent)
        style.headIndent = head
        style.firstLineHeadIndent = head
        style.paragraphSpacing = blockSpacing
        style.paragraphSpacingBefore = 0
        string.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: string.length)
        )
    }

    // MARK: - Inline code marker

    private static func markInlineCodeRuns(in string: NSMutableAttributedString) {
        let inlineBg = PlatformColors.inlineCodeBackground
        string.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: string.length),
            options: []
        ) { value, range, _ in
            guard let color = value as? PlatformColor, color == inlineBg else { return }
            string.addAttribute(.chatMarkdownInlineCode, value: true, range: range)
        }
    }

    // MARK: - Block kind stamping

    private static func stampBlockKind(
        _ kind: ChatMarkdownBlockKind,
        on string: NSMutableAttributedString,
        range: NSRange
    ) {
        guard range.length > 0 else { return }
        string.addAttribute(.chatMarkdownBlockKind, value: kind.rawValue, range: range)
    }

    private static func stampBlockID(
        _ id: BlockID,
        on string: NSMutableAttributedString,
        range: NSRange
    ) {
        guard range.length > 0 else { return }
        string.addAttribute(
            .chatMarkdownBlockID,
            value: NSNumber(value: id.fingerprint),
            range: range
        )
    }
}

extension ChatMarkdownBlock {
    var kind: ChatMarkdownBlockKind {
        switch self {
        case .heading: return .heading
        case .paragraph: return .paragraph
        case .codeBlock: return .codeBlock
        case .unorderedList: return .unorderedList
        case .orderedList: return .orderedList
        case .blockquote: return .blockquote
        case .table: return .table
        case .horizontalRule: return .horizontalRule
        }
    }
}

#endif
