import Foundation
import SwiftUI

enum BlockToAttributed {
    // MARK: - SwiftUI-scope AttributedString

    static func render(blocks: [ChatMarkdownBlock], theme: ChatMarkdownTheme) -> AttributedString {
        var out = AttributedString()
        for (i, block) in blocks.enumerated() {
            appendBlock(block, into: &out, theme: theme, indent: 0)
            if i < blocks.count - 1 {
                out.append(AttributedString("\n\n"))
            }
        }
        return out
    }

    private static func appendBlock(
        _ block: ChatMarkdownBlock,
        into out: inout AttributedString,
        theme: ChatMarkdownTheme,
        indent: Int
    ) {
        let pad = String(repeating: " ", count: indent * 2)
        switch block {
        case .heading(let level, let inlines):
            let font = theme.headingFonts[level] ?? theme.bodyFont
            if !pad.isEmpty { out.append(AttributedString(pad)) }
            out.append(InlineAttributedStringBuilder.build(inlines, theme: theme, baseFont: font))

        case .paragraph(let inlines):
            if !pad.isEmpty { out.append(AttributedString(pad)) }
            out.append(InlineAttributedStringBuilder.build(inlines, theme: theme, baseFont: theme.bodyFont))

        case .codeBlock(let language, let code, _):
            if let lang = language, !lang.isEmpty {
                var header = AttributedString(pad + lang.lowercased() + "\n")
                header.font = theme.codeFont
                header.foregroundColor = theme.secondaryTextColor
                out.append(header)
            }
            let body = code.split(separator: "\n", omittingEmptySubsequences: false)
                .map { pad + String($0) }
                .joined(separator: "\n")
            var run = AttributedString(body)
            run.font = theme.codeFont
            run.foregroundColor = theme.textColor
            run.backgroundColor = theme.codeBackground
            out.append(run)

        case .unorderedList(let items):
            for (idx, item) in items.enumerated() {
                appendListItem(
                    marker: "• ",
                    item: item,
                    into: &out,
                    theme: theme,
                    indent: indent
                )
                if idx < items.count - 1 { out.append(AttributedString("\n")) }
            }

        case .orderedList(let start, let items):
            for (idx, item) in items.enumerated() {
                appendListItem(
                    marker: "\(start + idx). ",
                    item: item,
                    into: &out,
                    theme: theme,
                    indent: indent
                )
                if idx < items.count - 1 { out.append(AttributedString("\n")) }
            }

        case .blockquote(let blocks):
            for (idx, sub) in blocks.enumerated() {
                if !pad.isEmpty { out.append(AttributedString(pad)) }
                var prefix = AttributedString("│ ")
                prefix.foregroundColor = theme.blockquoteRuleColor
                out.append(prefix)
                appendBlock(sub, into: &out, theme: theme, indent: indent)
                if idx < blocks.count - 1 { out.append(AttributedString("\n")) }
            }

        case .table(let headers, let rows, _):
            appendTable(headers: headers, rows: rows, into: &out, theme: theme, pad: pad)

        case .horizontalRule:
            var rule = AttributedString(pad + "────────────────────")
            rule.foregroundColor = theme.horizontalRuleColor
            out.append(rule)
        }
    }

    private static func appendListItem(
        marker: String,
        item: [ChatMarkdownBlock],
        into out: inout AttributedString,
        theme: ChatMarkdownTheme,
        indent: Int
    ) {
        let pad = String(repeating: " ", count: indent * 2)
        out.append(AttributedString(pad + marker))
        for (i, sub) in item.enumerated() {
            appendBlock(sub, into: &out, theme: theme, indent: indent + 1)
            if i < item.count - 1 { out.append(AttributedString("\n")) }
        }
    }

    private static func appendTable(
        headers: [[ChatMarkdownInline]],
        rows: [[[ChatMarkdownInline]]],
        into out: inout AttributedString,
        theme: ChatMarkdownTheme,
        pad: String
    ) {
        let allRows: [[String]] = ([headers] + rows).map { row in
            row.map { plainText(of: $0) }
        }
        let columnCount = allRows.map(\.count).max() ?? 0
        var widths = Array(repeating: 0, count: columnCount)
        for row in allRows {
            for (i, cell) in row.enumerated() {
                widths[i] = max(widths[i], cell.count)
            }
        }
        func formatRow(_ row: [String]) -> String {
            var parts: [String] = []
            for i in 0..<columnCount {
                let cell = i < row.count ? row[i] : ""
                parts.append(cell.padding(toLength: widths[i], withPad: " ", startingAt: 0))
            }
            return pad + parts.joined(separator: "  ")
        }
        let separator = pad + widths.map { String(repeating: "─", count: $0) }.joined(separator: "  ")

        var headerLine = AttributedString(formatRow(allRows[0]) + "\n")
        headerLine.font = theme.bodyFont
        out.append(headerLine)
        out.append(AttributedString(separator + "\n"))
        for (i, row) in rows.enumerated() {
            out.append(AttributedString(formatRow(row.map { plainText(of: $0) })))
            if i < rows.count - 1 { out.append(AttributedString("\n")) }
        }
    }

    private static func plainText(of inlines: [ChatMarkdownInline]) -> String {
        var s = ""
        for i in inlines { plainText(of: i, into: &s) }
        return s
    }

    private static func plainText(of inline: ChatMarkdownInline, into out: inout String) {
        switch inline {
        case .text(let s): out.append(s)
        case .bold(let xs), .italic(let xs): xs.forEach { plainText(of: $0, into: &out) }
        case .code(let s): out.append(s)
        case .link(let xs, _): xs.forEach { plainText(of: $0, into: &out) }
        case .lineBreak: out.append(" ")
        }
    }

    // MARK: - NSAttributedString

    static func renderNS(blocks: [ChatMarkdownBlock], theme: ChatMarkdownTheme) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for (i, block) in blocks.enumerated() {
            appendNSBlock(block, into: out, theme: theme, indent: 0)
            if i < blocks.count - 1 {
                out.append(NSAttributedString(string: "\n\n"))
            }
        }
        return out
    }

    private static func appendNSBlock(
        _ block: ChatMarkdownBlock,
        into out: NSMutableAttributedString,
        theme: ChatMarkdownTheme,
        indent: Int
    ) {
        let pad = String(repeating: " ", count: indent * 2)
        switch block {
        case .heading(let level, let inlines):
            let font = TextKitThemeAdapter.headingFont(level: level, theme: theme)
            if !pad.isEmpty {
                out.append(NSAttributedString(string: pad, attributes: [.font: font]))
            }
            out.append(NSInlineBuilder.build(
                inlines,
                baseFont: font,
                baseColor: PlatformColors.primary,
                inlineCodeFont: TextKitThemeAdapter.inlineCodeFont(for: theme)
            ))

        case .paragraph(let inlines):
            let font = TextKitThemeAdapter.bodyFont(for: theme)
            if !pad.isEmpty {
                out.append(NSAttributedString(string: pad, attributes: [.font: font]))
            }
            out.append(NSInlineBuilder.build(
                inlines,
                baseFont: font,
                baseColor: PlatformColors.primary,
                inlineCodeFont: TextKitThemeAdapter.inlineCodeFont(for: theme)
            ))

        case .codeBlock(let language, let code, _):
            let mono = TextKitThemeAdapter.codeFont(for: theme)
            if let lang = language, !lang.isEmpty {
                let header = NSAttributedString(
                    string: pad + lang.lowercased() + "\n",
                    attributes: [
                        .font: mono,
                        .foregroundColor: PlatformColors.secondary,
                    ]
                )
                out.append(header)
            }
            let body = code.split(separator: "\n", omittingEmptySubsequences: false)
                .map { pad + String($0) }
                .joined(separator: "\n")
            out.append(NSAttributedString(
                string: body,
                attributes: [
                    .font: mono,
                    .foregroundColor: PlatformColors.primary,
                    .backgroundColor: PlatformColors.codeBackground,
                ]
            ))

        case .unorderedList(let items):
            for (idx, item) in items.enumerated() {
                appendNSListItem(marker: "• ", item: item, into: out, theme: theme, indent: indent)
                if idx < items.count - 1 { out.append(NSAttributedString(string: "\n")) }
            }

        case .orderedList(let start, let items):
            for (idx, item) in items.enumerated() {
                appendNSListItem(marker: "\(start + idx). ", item: item, into: out, theme: theme, indent: indent)
                if idx < items.count - 1 { out.append(NSAttributedString(string: "\n")) }
            }

        case .blockquote(let blocks):
            for (idx, sub) in blocks.enumerated() {
                if !pad.isEmpty {
                    out.append(NSAttributedString(string: pad))
                }
                out.append(NSAttributedString(
                    string: "│ ",
                    attributes: [.foregroundColor: PlatformColors.secondary]
                ))
                appendNSBlock(sub, into: out, theme: theme, indent: indent)
                if idx < blocks.count - 1 { out.append(NSAttributedString(string: "\n")) }
            }

        case .table(let headers, let rows, _):
            appendNSTable(headers: headers, rows: rows, into: out, theme: theme, pad: pad)

        case .horizontalRule:
            out.append(NSAttributedString(
                string: pad + "────────────────────",
                attributes: [.foregroundColor: PlatformColors.secondary]
            ))
        }
    }

    private static func appendNSListItem(
        marker: String,
        item: [ChatMarkdownBlock],
        into out: NSMutableAttributedString,
        theme: ChatMarkdownTheme,
        indent: Int
    ) {
        let pad = String(repeating: " ", count: indent * 2)
        out.append(NSAttributedString(
            string: pad + marker,
            attributes: [.font: TextKitThemeAdapter.bodyFont(for: theme)]
        ))
        for (i, sub) in item.enumerated() {
            appendNSBlock(sub, into: out, theme: theme, indent: indent + 1)
            if i < item.count - 1 { out.append(NSAttributedString(string: "\n")) }
        }
    }

    private static func appendNSTable(
        headers: [[ChatMarkdownInline]],
        rows: [[[ChatMarkdownInline]]],
        into out: NSMutableAttributedString,
        theme: ChatMarkdownTheme,
        pad: String
    ) {
        let font = TextKitThemeAdapter.codeFont(for: theme)
        let allRows: [[String]] = ([headers] + rows).map { row in
            row.map { plainText(of: $0) }
        }
        let columnCount = allRows.map(\.count).max() ?? 0
        var widths = Array(repeating: 0, count: columnCount)
        for row in allRows {
            for (i, cell) in row.enumerated() {
                widths[i] = max(widths[i], cell.count)
            }
        }
        func formatRow(_ row: [String]) -> String {
            var parts: [String] = []
            for i in 0..<columnCount {
                let cell = i < row.count ? row[i] : ""
                parts.append(cell.padding(toLength: widths[i], withPad: " ", startingAt: 0))
            }
            return pad + parts.joined(separator: "  ")
        }
        let separator = pad + widths.map { String(repeating: "─", count: $0) }.joined(separator: "  ")
        out.append(NSAttributedString(
            string: formatRow(allRows[0]) + "\n",
            attributes: [.font: font]
        ))
        out.append(NSAttributedString(
            string: separator + "\n",
            attributes: [.font: font]
        ))
        for (i, row) in rows.enumerated() {
            out.append(NSAttributedString(
                string: formatRow(row.map { plainText(of: $0) }),
                attributes: [.font: font]
            ))
            if i < rows.count - 1 { out.append(NSAttributedString(string: "\n")) }
        }
    }
}
