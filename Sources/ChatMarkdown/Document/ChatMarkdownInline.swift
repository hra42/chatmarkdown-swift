import Foundation

public indirect enum ChatMarkdownInline: Hashable, Sendable, Codable {
    case text(String)
    case bold([ChatMarkdownInline])
    case italic([ChatMarkdownInline])
    case code(String)
    case link(text: [ChatMarkdownInline], url: String)
    case lineBreak

    private enum CodingKeys: String, CodingKey {
        case kind, value, children, url
    }

    private enum Kind: String, Codable {
        case text, bold, italic, code, link, lineBreak
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode(Kind.text, forKey: .kind)
            try c.encode(s, forKey: .value)
        case .bold(let xs):
            try c.encode(Kind.bold, forKey: .kind)
            try c.encode(xs, forKey: .children)
        case .italic(let xs):
            try c.encode(Kind.italic, forKey: .kind)
            try c.encode(xs, forKey: .children)
        case .code(let s):
            try c.encode(Kind.code, forKey: .kind)
            try c.encode(s, forKey: .value)
        case .link(let text, let url):
            try c.encode(Kind.link, forKey: .kind)
            try c.encode(text, forKey: .children)
            try c.encode(url, forKey: .url)
        case .lineBreak:
            try c.encode(Kind.lineBreak, forKey: .kind)
        }
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .text:
            self = .text(try c.decode(String.self, forKey: .value))
        case .bold:
            self = .bold(try c.decode([ChatMarkdownInline].self, forKey: .children))
        case .italic:
            self = .italic(try c.decode([ChatMarkdownInline].self, forKey: .children))
        case .code:
            self = .code(try c.decode(String.self, forKey: .value))
        case .link:
            self = .link(
                text: try c.decode([ChatMarkdownInline].self, forKey: .children),
                url: try c.decode(String.self, forKey: .url)
            )
        case .lineBreak:
            self = .lineBreak
        }
    }

    func hashInto(_ h: inout StableHash) {
        switch self {
        case .text(let s):
            h.combine(tag: 1); h.combine(s)
        case .bold(let xs):
            h.combine(tag: 2); h.combine(xs.count)
            for x in xs { x.hashInto(&h) }
        case .italic(let xs):
            h.combine(tag: 3); h.combine(xs.count)
            for x in xs { x.hashInto(&h) }
        case .code(let s):
            h.combine(tag: 4); h.combine(s)
        case .link(let text, let url):
            h.combine(tag: 5); h.combine(url); h.combine(text.count)
            for x in text { x.hashInto(&h) }
        case .lineBreak:
            h.combine(tag: 6)
        }
    }
}
