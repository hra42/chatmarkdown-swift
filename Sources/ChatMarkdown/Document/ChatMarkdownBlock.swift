import Foundation

public enum TableAlignment: String, Hashable, Sendable, Codable {
    case left, center, right, none
}

public indirect enum ChatMarkdownBlock: Hashable, Sendable, Codable {
    case heading(level: Int, inlines: [ChatMarkdownInline])
    case paragraph(inlines: [ChatMarkdownInline])
    case codeBlock(language: String?, code: String, isClosed: Bool)
    case unorderedList(items: [[ChatMarkdownBlock]])
    case orderedList(start: Int, items: [[ChatMarkdownBlock]])
    case blockquote(blocks: [ChatMarkdownBlock])
    case table(headers: [[ChatMarkdownInline]], rows: [[[ChatMarkdownInline]]], alignments: [TableAlignment])
    case horizontalRule

    private enum CodingKeys: String, CodingKey {
        case kind, level, inlines, language, code, isClosed
        case start, items, blocks, headers, rows, alignments
    }

    private enum Kind: String, Codable {
        case heading, paragraph, codeBlock, unorderedList, orderedList,
             blockquote, table, horizontalRule
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .heading(let level, let inlines):
            try c.encode(Kind.heading, forKey: .kind)
            try c.encode(level, forKey: .level)
            try c.encode(inlines, forKey: .inlines)
        case .paragraph(let inlines):
            try c.encode(Kind.paragraph, forKey: .kind)
            try c.encode(inlines, forKey: .inlines)
        case .codeBlock(let language, let code, let isClosed):
            try c.encode(Kind.codeBlock, forKey: .kind)
            try c.encodeIfPresent(language, forKey: .language)
            try c.encode(code, forKey: .code)
            try c.encode(isClosed, forKey: .isClosed)
        case .unorderedList(let items):
            try c.encode(Kind.unorderedList, forKey: .kind)
            try c.encode(items, forKey: .items)
        case .orderedList(let start, let items):
            try c.encode(Kind.orderedList, forKey: .kind)
            try c.encode(start, forKey: .start)
            try c.encode(items, forKey: .items)
        case .blockquote(let blocks):
            try c.encode(Kind.blockquote, forKey: .kind)
            try c.encode(blocks, forKey: .blocks)
        case .table(let headers, let rows, let alignments):
            try c.encode(Kind.table, forKey: .kind)
            try c.encode(headers, forKey: .headers)
            try c.encode(rows, forKey: .rows)
            try c.encode(alignments, forKey: .alignments)
        case .horizontalRule:
            try c.encode(Kind.horizontalRule, forKey: .kind)
        }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .heading:
            self = .heading(
                level: try c.decode(Int.self, forKey: .level),
                inlines: try c.decode([ChatMarkdownInline].self, forKey: .inlines)
            )
        case .paragraph:
            self = .paragraph(inlines: try c.decode([ChatMarkdownInline].self, forKey: .inlines))
        case .codeBlock:
            self = .codeBlock(
                language: try c.decodeIfPresent(String.self, forKey: .language),
                code: try c.decode(String.self, forKey: .code),
                isClosed: try c.decode(Bool.self, forKey: .isClosed)
            )
        case .unorderedList:
            self = .unorderedList(items: try c.decode([[ChatMarkdownBlock]].self, forKey: .items))
        case .orderedList:
            self = .orderedList(
                start: try c.decode(Int.self, forKey: .start),
                items: try c.decode([[ChatMarkdownBlock]].self, forKey: .items)
            )
        case .blockquote:
            self = .blockquote(blocks: try c.decode([ChatMarkdownBlock].self, forKey: .blocks))
        case .table:
            self = .table(
                headers: try c.decode([[ChatMarkdownInline]].self, forKey: .headers),
                rows: try c.decode([[[ChatMarkdownInline]]].self, forKey: .rows),
                alignments: try c.decode([TableAlignment].self, forKey: .alignments)
            )
        case .horizontalRule:
            self = .horizontalRule
        }
    }

    public var contentHash: UInt64 {
        var h = StableHash()
        hashInto(&h)
        return h.value
    }

    func hashInto(_ h: inout StableHash) {
        switch self {
        case .heading(let level, let inlines):
            h.combine(tag: 10); h.combine(level); h.combine(inlines.count)
            for x in inlines { x.hashInto(&h) }
        case .paragraph(let inlines):
            h.combine(tag: 11); h.combine(inlines.count)
            for x in inlines { x.hashInto(&h) }
        case .codeBlock(let language, let code, let isClosed):
            h.combine(tag: 12)
            h.combine(language ?? "")
            h.combine(code)
            h.combine(isClosed)
        case .unorderedList(let items):
            h.combine(tag: 13); h.combine(items.count)
            for item in items {
                h.combine(item.count)
                for b in item { b.hashInto(&h) }
            }
        case .orderedList(let start, let items):
            h.combine(tag: 14); h.combine(start); h.combine(items.count)
            for item in items {
                h.combine(item.count)
                for b in item { b.hashInto(&h) }
            }
        case .blockquote(let blocks):
            h.combine(tag: 15); h.combine(blocks.count)
            for b in blocks { b.hashInto(&h) }
        case .table(let headers, let rows, let alignments):
            h.combine(tag: 16)
            h.combine(headers.count)
            for cell in headers {
                h.combine(cell.count)
                for x in cell { x.hashInto(&h) }
            }
            h.combine(rows.count)
            for row in rows {
                h.combine(row.count)
                for cell in row {
                    h.combine(cell.count)
                    for x in cell { x.hashInto(&h) }
                }
            }
            h.combine(alignments.count)
            for a in alignments { h.combine(a.rawValue) }
        case .horizontalRule:
            h.combine(tag: 17)
        }
    }
}
