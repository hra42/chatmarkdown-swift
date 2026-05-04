import Foundation
import Markdown

struct MarkupNormalizer {
    static func blocks(from document: Markdown.Document) -> [ChatMarkdownBlock] {
        var result: [ChatMarkdownBlock] = []
        for child in document.blockChildren {
            if let b = block(from: child) {
                result.append(b)
            }
        }
        return result
    }

    private static func listItemBlocks(from item: ListItem) -> [ChatMarkdownBlock] {
        Array(item.blockChildren.compactMap { block(from: $0) })
    }

    private static func block(from markup: any BlockMarkup) -> ChatMarkdownBlock? {
        switch markup {
        case let h as Heading:
            return .heading(level: h.level, inlines: inlines(from: h.inlineChildren))
        case let p as Paragraph:
            let xs = inlines(from: p.inlineChildren)
            return xs.isEmpty ? nil : .paragraph(inlines: xs)
        case let cb as CodeBlock:
            return .codeBlock(
                language: cb.language?.lowercased(),
                code: cb.code,
                isClosed: true
            )
        case let ul as UnorderedList:
            let items = Array(ul.listItems.map { listItemBlocks(from: $0) })
            return .unorderedList(items: items)
        case let ol as OrderedList:
            let items = Array(ol.listItems.map { listItemBlocks(from: $0) })
            return .orderedList(start: Int(ol.startIndex), items: items)
        case let bq as BlockQuote:
            let inner = Array(bq.blockChildren.compactMap { block(from: $0) })
            return .blockquote(blocks: inner)
        case let t as Markdown.Table:
            return tableBlock(from: t)
        case is ThematicBreak:
            return .horizontalRule
        default:
            // HTML blocks, block directives, custom blocks, doxygen, etc. dropped silently.
            return nil
        }
    }

    private static func tableBlock(from t: Markdown.Table) -> ChatMarkdownBlock {
        let headerCells: [[ChatMarkdownInline]] = t.head.cells.map {
            inlines(from: $0.inlineChildren)
        }
        let rowsList: [[[ChatMarkdownInline]]] = t.body.rows.map { row in
            row.cells.map { inlines(from: $0.inlineChildren) }
        }
        let alignments: [TableAlignment] = t.columnAlignments.map { mapAlignment($0) }
        return .table(headers: headerCells, rows: rowsList, alignments: alignments)
    }

    private static func mapAlignment(_ a: Markdown.Table.ColumnAlignment?) -> TableAlignment {
        switch a {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .none: return .none
        }
    }

    private static func inlines<S: Sequence>(from markups: S) -> [ChatMarkdownInline]
        where S.Element == InlineMarkup
    {
        var out: [ChatMarkdownInline] = []
        for m in markups {
            if let x = inline(from: m) {
                out.append(x)
            }
        }
        return out
    }

    private static func inline(from markup: any InlineMarkup) -> ChatMarkdownInline? {
        switch markup {
        case let t as Markdown.Text:
            return .text(t.string)
        case let s as Strong:
            return .bold(inlines(from: s.inlineChildren))
        case let e as Emphasis:
            return .italic(inlines(from: e.inlineChildren))
        case let c as InlineCode:
            return .code(c.code)
        case let l as Markdown.Link:
            return .link(text: inlines(from: l.inlineChildren), url: l.destination ?? "")
        case is LineBreak:
            return .lineBreak
        case is SoftBreak:
            // Preserve word spacing across soft-wrapped lines.
            return .text(" ")
        default:
            // Images, inline HTML, custom inline, symbol links, strikethrough, attributes — dropped.
            return nil
        }
    }
}
