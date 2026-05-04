import Foundation
import SwiftUI

enum InlineAttributedStringBuilder {
    static func build(
        _ inlines: [ChatMarkdownInline],
        theme: ChatMarkdownTheme,
        baseFont: Font
    ) -> AttributedString {
        var result = AttributedString()
        let initialAttrs = makeBaseAttributes(font: baseFont, color: theme.textColor)
        for inline in inlines {
            append(inline, into: &result, attrs: initialAttrs, theme: theme)
        }
        return result
    }

    private static func makeBaseAttributes(font: Font, color: Color) -> RenderAttributes {
        RenderAttributes(
            font: font,
            isBold: false,
            isItalic: false,
            color: color,
            isCode: false,
            link: nil
        )
    }

    private static func append(
        _ inline: ChatMarkdownInline,
        into result: inout AttributedString,
        attrs: RenderAttributes,
        theme: ChatMarkdownTheme
    ) {
        switch inline {
        case .text(let s):
            result.append(makeAttributedString(s, attrs: attrs, theme: theme))
        case .bold(let children):
            var inner = attrs
            inner.isBold = true
            for child in children {
                append(child, into: &result, attrs: inner, theme: theme)
            }
        case .italic(let children):
            var inner = attrs
            inner.isItalic = true
            for child in children {
                append(child, into: &result, attrs: inner, theme: theme)
            }
        case .code(let s):
            var codeAttrs = attrs
            codeAttrs.isCode = true
            result.append(makeAttributedString(s, attrs: codeAttrs, theme: theme))
        case .link(let children, let url):
            var inner = attrs
            inner.link = URL(string: url)
            for child in children {
                append(child, into: &result, attrs: inner, theme: theme)
            }
        case .lineBreak:
            result.append(AttributedString("\n"))
        }
    }

    private static func makeAttributedString(
        _ s: String,
        attrs: RenderAttributes,
        theme: ChatMarkdownTheme
    ) -> AttributedString {
        var part = AttributedString(s)

        if attrs.isCode {
            part.font = applyTraits(theme.inlineCodeFont, bold: attrs.isBold, italic: attrs.isItalic)
            part.backgroundColor = theme.inlineCodeBackground
        } else {
            part.font = applyTraits(attrs.font, bold: attrs.isBold, italic: attrs.isItalic)
        }

        if let link = attrs.link {
            part.link = link
            part.foregroundColor = theme.linkColor
            if theme.linksUnderlined {
                part.underlineStyle = .single
            }
        } else {
            part.foregroundColor = attrs.color
        }

        return part
    }

    private static func applyTraits(_ font: Font, bold: Bool, italic: Bool) -> Font {
        var f = font
        if bold { f = f.bold() }
        if italic { f = f.italic() }
        return f
    }

    private struct RenderAttributes {
        var font: Font
        var isBold: Bool
        var isItalic: Bool
        var color: Color
        var isCode: Bool
        var link: URL?
    }
}
