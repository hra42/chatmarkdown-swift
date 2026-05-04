import Foundation

/// Renders a `ChatMarkdownDocument` to plain text suitable for TTS playback
/// or any consumer that wants Markdown stripped out.
public enum ChatMarkdownPlainTextRenderer {
    public static func render(
        _ markdown: String,
        options: PlainTextOptions = .ttsDefaults
    ) -> String {
        render(document: ChatMarkdownDocument(markdown: markdown), options: options)
    }

    public static func render(
        document: ChatMarkdownDocument,
        options: PlainTextOptions = .ttsDefaults
    ) -> String {
        var pieces: [String] = []
        for block in document.blocks {
            if let s = renderBlock(block, options: options), !s.isEmpty {
                pieces.append(s)
            }
        }
        return pieces.joined(separator: options.paragraphSeparator)
    }

    private static func renderBlock(_ block: ChatMarkdownBlock, options: PlainTextOptions) -> String? {
        switch block {
        case .heading(_, let inlines):
            return renderInlines(inlines, options: options)

        case .paragraph(let inlines):
            return renderInlines(inlines, options: options)

        case .codeBlock(_, let code, _):
            switch options.codeBlockHandling {
            case .drop: return nil
            case .marker(let m): return m
            case .keepText: return code
            }

        case .unorderedList(let items):
            return renderListItems(items, ordered: false, start: 1, options: options)

        case .orderedList(let start, let items):
            return renderListItems(items, ordered: true, start: start, options: options)

        case .blockquote(let blocks):
            var sub: [String] = []
            for b in blocks {
                if let s = renderBlock(b, options: options), !s.isEmpty {
                    sub.append(s)
                }
            }
            return sub.joined(separator: options.paragraphSeparator)

        case .table(let headers, let rows, _):
            return renderTable(headers: headers, rows: rows, options: options)

        case .horizontalRule:
            return nil
        }
    }

    private static func renderListItems(
        _ items: [[ChatMarkdownBlock]],
        ordered: Bool,
        start: Int,
        options: PlainTextOptions
    ) -> String {
        var lines: [String] = []
        for (idx, item) in items.enumerated() {
            var sub: [String] = []
            for b in item {
                if let s = renderBlock(b, options: options), !s.isEmpty {
                    sub.append(s)
                }
            }
            let body = sub.joined(separator: " ")
            let prefix: String
            switch options.listMarkerStyle {
            case .none: prefix = ""
            case .bullet: prefix = "• "
            case .ordinal: prefix = ordered ? "\(start + idx). " : "• "
            }
            lines.append(prefix + body)
        }
        return lines.joined(separator: "\n")
    }

    private static func renderTable(
        headers: [[ChatMarkdownInline]],
        rows: [[[ChatMarkdownInline]]],
        options: PlainTextOptions
    ) -> String {
        var lines: [String] = []
        let headerStrings = headers.map { renderInlines($0, options: options) }
        if !headerStrings.isEmpty {
            lines.append(headerStrings.joined(separator: " — "))
        }
        for row in rows {
            let cells = row.map { renderInlines($0, options: options) }
            lines.append(cells.joined(separator: " — "))
        }
        return lines.joined(separator: "\n")
    }

    private static func renderInlines(_ inlines: [ChatMarkdownInline], options: PlainTextOptions) -> String {
        var out = ""
        for i in inlines { renderInline(i, options: options, into: &out) }
        return out
    }

    private static func renderInline(
        _ inline: ChatMarkdownInline,
        options: PlainTextOptions,
        into out: inout String
    ) {
        switch inline {
        case .text(let s):
            out += s
        case .bold(let xs), .italic(let xs):
            for x in xs { renderInline(x, options: options, into: &out) }
        case .code(let s):
            out += s
        case .link(let xs, let url):
            for x in xs { renderInline(x, options: options, into: &out) }
            if options.linkRendering == .textThenURL {
                out += " (\(url))"
            }
        case .lineBreak:
            out += " "
        }
    }
}
