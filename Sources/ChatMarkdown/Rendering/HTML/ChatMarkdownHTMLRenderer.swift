import Foundation

/// Renders a `ChatMarkdownDocument` to a self-contained HTML string suitable
/// for the rich-text clipboard (`NSPasteboard` / `UIPasteboard`).
public enum ChatMarkdownHTMLRenderer {
    public static func render(
        _ markdown: String,
        embedStyles: Bool = true
    ) -> String {
        render(document: ChatMarkdownDocument(markdown: markdown), embedStyles: embedStyles)
    }

    public static func render(
        document: ChatMarkdownDocument,
        embedStyles: Bool = true
    ) -> String {
        var out = ""
        if embedStyles {
            out += HTMLDefaultStyles.css
            out += "\n"
        }
        for block in document.blocks {
            renderBlock(block, into: &out)
            out += "\n"
        }
        return out
    }

    // MARK: - Blocks

    private static func renderBlock(_ block: ChatMarkdownBlock, into out: inout String) {
        switch block {
        case .heading(let level, let inlines):
            let tag = "h\(min(max(level, 1), 6))"
            out += "<\(tag)>"
            renderInlines(inlines, into: &out)
            out += "</\(tag)>"

        case .paragraph(let inlines):
            out += "<p>"
            renderInlines(inlines, into: &out)
            out += "</p>"

        case .codeBlock(let language, let code, _):
            if let lang = language, !lang.isEmpty {
                out += "<pre><code class=\"language-\(HTMLEscaping.text(lang.lowercased()))\">"
            } else {
                out += "<pre><code>"
            }
            out += HTMLEscaping.text(code)
            out += "</code></pre>"

        case .unorderedList(let items):
            out += "<ul>"
            for item in items {
                out += "<li>"
                renderItemBlocks(item, into: &out)
                out += "</li>"
            }
            out += "</ul>"

        case .orderedList(let start, let items):
            if start == 1 {
                out += "<ol>"
            } else {
                out += "<ol start=\"\(start)\">"
            }
            for item in items {
                out += "<li>"
                renderItemBlocks(item, into: &out)
                out += "</li>"
            }
            out += "</ol>"

        case .blockquote(let blocks):
            out += "<blockquote>"
            for sub in blocks {
                renderBlock(sub, into: &out)
            }
            out += "</blockquote>"

        case .table(let headers, let rows, let alignments):
            renderTable(headers: headers, rows: rows, alignments: alignments, into: &out)

        case .horizontalRule:
            out += "<hr>"
        }
    }

    /// In `<li>` we want a paragraph-only item to render inline (no `<p>`)
    /// so list items don't get extra vertical padding from the browser.
    private static func renderItemBlocks(_ blocks: [ChatMarkdownBlock], into out: inout String) {
        if blocks.count == 1, case .paragraph(let inlines) = blocks[0] {
            renderInlines(inlines, into: &out)
            return
        }
        for sub in blocks {
            renderBlock(sub, into: &out)
        }
    }

    private static func renderTable(
        headers: [[ChatMarkdownInline]],
        rows: [[[ChatMarkdownInline]]],
        alignments: [TableAlignment],
        into out: inout String
    ) {
        out += "<table><thead><tr>"
        for (i, cell) in headers.enumerated() {
            let alignAttr = alignAttribute(alignments, i)
            out += "<th\(alignAttr)>"
            renderInlines(cell, into: &out)
            out += "</th>"
        }
        out += "</tr></thead><tbody>"
        for row in rows {
            out += "<tr>"
            for (i, cell) in row.enumerated() {
                let alignAttr = alignAttribute(alignments, i)
                out += "<td\(alignAttr)>"
                renderInlines(cell, into: &out)
                out += "</td>"
            }
            out += "</tr>"
        }
        out += "</tbody></table>"
    }

    private static func alignAttribute(_ alignments: [TableAlignment], _ i: Int) -> String {
        guard i < alignments.count else { return "" }
        switch alignments[i] {
        case .left: return " style=\"text-align:left\""
        case .right: return " style=\"text-align:right\""
        case .center: return " style=\"text-align:center\""
        case .none: return ""
        }
    }

    // MARK: - Inlines

    private static func renderInlines(_ inlines: [ChatMarkdownInline], into out: inout String) {
        for inline in inlines {
            renderInline(inline, into: &out)
        }
    }

    private static func renderInline(_ inline: ChatMarkdownInline, into out: inout String) {
        switch inline {
        case .text(let s):
            out += HTMLEscaping.text(s)
        case .bold(let xs):
            out += "<strong>"
            renderInlines(xs, into: &out)
            out += "</strong>"
        case .italic(let xs):
            out += "<em>"
            renderInlines(xs, into: &out)
            out += "</em>"
        case .code(let s):
            out += "<code>" + HTMLEscaping.text(s) + "</code>"
        case .link(let xs, let url):
            out += "<a href=\"" + HTMLEscaping.href(url) + "\">"
            renderInlines(xs, into: &out)
            out += "</a>"
        case .lineBreak:
            out += "<br>"
        }
    }
}
