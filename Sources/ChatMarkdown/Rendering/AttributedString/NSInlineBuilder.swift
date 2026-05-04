import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

enum NSInlineBuilder {
    static func build(
        _ inlines: [ChatMarkdownInline],
        baseFont: PlatformFont,
        baseColor: PlatformColor,
        inlineCodeFont: PlatformFont? = nil
    ) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let attrs = Attrs(
            font: baseFont,
            isBold: false,
            isItalic: false,
            color: baseColor,
            isCode: false,
            link: nil,
            inlineCodeFont: inlineCodeFont
        )
        for inline in inlines {
            append(inline, into: out, attrs: attrs)
        }
        return out
    }

    private static func append(
        _ inline: ChatMarkdownInline,
        into out: NSMutableAttributedString,
        attrs: Attrs
    ) {
        switch inline {
        case .text(let s):
            out.append(makePart(s, attrs: attrs))
        case .bold(let children):
            var inner = attrs
            inner.isBold = true
            for c in children { append(c, into: out, attrs: inner) }
        case .italic(let children):
            var inner = attrs
            inner.isItalic = true
            for c in children { append(c, into: out, attrs: inner) }
        case .code(let s):
            var inner = attrs
            inner.isCode = true
            out.append(makePart(s, attrs: inner))
        case .link(let children, let url):
            var inner = attrs
            inner.link = URL(string: url)
            for c in children { append(c, into: out, attrs: inner) }
        case .lineBreak:
            out.append(NSAttributedString(string: "\n"))
        }
    }

    private static func makePart(_ s: String, attrs: Attrs) -> NSAttributedString {
        var font: PlatformFont
        if attrs.isCode {
            font = attrs.inlineCodeFont ?? PlatformFonts.monospaced(size: attrs.font.pointSize)
        } else {
            font = attrs.font
        }
        if attrs.isBold { font = PlatformFonts.bold(font) }
        if attrs.isItalic { font = PlatformFonts.italic(font) }

        var dict: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: attrs.link != nil ? PlatformColors.link : attrs.color,
        ]
        if attrs.isCode {
            dict[.backgroundColor] = PlatformColors.inlineCodeBackground
        }
        if let url = attrs.link {
            dict[.link] = url
            dict[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return NSAttributedString(string: s, attributes: dict)
    }

    private struct Attrs {
        var font: PlatformFont
        var isBold: Bool
        var isItalic: Bool
        var color: PlatformColor
        var isCode: Bool
        var link: URL?
        var inlineCodeFont: PlatformFont?
    }
}

#endif
