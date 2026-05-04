import SwiftUI

public struct SyntaxPalette: Sendable, Hashable {
    public var keyword: Color
    public var string: Color
    public var comment: Color
    public var number: Color
    public var type: Color
    public var plain: Color

    public init(
        keyword: Color,
        string: Color,
        comment: Color,
        number: Color,
        type: Color,
        plain: Color
    ) {
        self.keyword = keyword
        self.string = string
        self.comment = comment
        self.number = number
        self.type = type
        self.plain = plain
    }
}

public struct ChatMarkdownTheme: Sendable {
    public var bodyFont: Font
    public var codeFont: Font
    public var inlineCodeFont: Font
    public var headingFonts: [Int: Font]

    public var textColor: Color
    public var secondaryTextColor: Color
    public var linkColor: Color
    public var linksUnderlined: Bool

    public var codeBackground: Color
    public var codeHeaderBackground: Color
    public var inlineCodeBackground: Color

    public var blockquoteRuleColor: Color
    public var tableBorderColor: Color
    public var horizontalRuleColor: Color

    public var blockSpacing: CGFloat
    public var listIndent: CGFloat
    public var textSelectionEnabled: Bool

    public var syntaxColors: SyntaxPalette

    public init(
        bodyFont: Font = .body,
        codeFont: Font = .system(.callout, design: .monospaced),
        inlineCodeFont: Font = .system(.body, design: .monospaced),
        headingFonts: [Int: Font] = ChatMarkdownTheme.defaultHeadingFonts,
        textColor: Color = .primary,
        secondaryTextColor: Color = .secondary,
        linkColor: Color = .accentColor,
        linksUnderlined: Bool = true,
        codeBackground: Color = Color.gray.opacity(0.12),
        codeHeaderBackground: Color = Color.gray.opacity(0.18),
        inlineCodeBackground: Color = Color.gray.opacity(0.18),
        blockquoteRuleColor: Color = Color.gray.opacity(0.5),
        tableBorderColor: Color = Color.gray.opacity(0.4),
        horizontalRuleColor: Color = Color.gray.opacity(0.4),
        blockSpacing: CGFloat = 8,
        listIndent: CGFloat = 16,
        textSelectionEnabled: Bool = true,
        syntaxColors: SyntaxPalette = .defaultLight
    ) {
        self.bodyFont = bodyFont
        self.codeFont = codeFont
        self.inlineCodeFont = inlineCodeFont
        self.headingFonts = headingFonts
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.linkColor = linkColor
        self.linksUnderlined = linksUnderlined
        self.codeBackground = codeBackground
        self.codeHeaderBackground = codeHeaderBackground
        self.inlineCodeBackground = inlineCodeBackground
        self.blockquoteRuleColor = blockquoteRuleColor
        self.tableBorderColor = tableBorderColor
        self.horizontalRuleColor = horizontalRuleColor
        self.blockSpacing = blockSpacing
        self.listIndent = listIndent
        self.textSelectionEnabled = textSelectionEnabled
        self.syntaxColors = syntaxColors
    }

    public static let defaultHeadingFonts: [Int: Font] = [
        1: .system(size: 28, weight: .bold),
        2: .system(size: 24, weight: .bold),
        3: .system(size: 20, weight: .semibold),
        4: .system(size: 18, weight: .semibold),
        5: .system(size: 16, weight: .semibold),
        6: .system(size: 15, weight: .semibold),
    ]
}

extension SyntaxPalette {
    public static let defaultLight = SyntaxPalette(
        keyword: Color(red: 0.65, green: 0.13, blue: 0.55),
        string: Color(red: 0.77, green: 0.10, blue: 0.09),
        comment: Color(red: 0.0, green: 0.5, blue: 0.0),
        number: Color(red: 0.10, green: 0.10, blue: 0.80),
        type: Color(red: 0.0, green: 0.45, blue: 0.65),
        plain: .primary
    )

    public static let defaultDark = SyntaxPalette(
        keyword: Color(red: 0.93, green: 0.45, blue: 0.78),
        string: Color(red: 0.98, green: 0.55, blue: 0.45),
        comment: Color(red: 0.42, green: 0.78, blue: 0.42),
        number: Color(red: 0.65, green: 0.78, blue: 1.0),
        type: Color(red: 0.55, green: 0.85, blue: 0.95),
        plain: .primary
    )

    public static let pdfLight = SyntaxPalette(
        keyword: Color(red: 0.55, green: 0.10, blue: 0.50),
        string: Color(red: 0.65, green: 0.10, blue: 0.10),
        comment: Color(red: 0.0, green: 0.45, blue: 0.0),
        number: Color(red: 0.10, green: 0.10, blue: 0.65),
        type: Color(red: 0.0, green: 0.40, blue: 0.55),
        plain: .black
    )
}
