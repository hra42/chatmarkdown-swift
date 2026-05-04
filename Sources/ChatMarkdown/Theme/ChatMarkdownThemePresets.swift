import SwiftUI

extension ChatMarkdownTheme {
    public static let assistant: ChatMarkdownTheme = ChatMarkdownTheme()

    public static let user: ChatMarkdownTheme = {
        var t = ChatMarkdownTheme()
        t.linkColor = .white
        t.textColor = .white
        t.secondaryTextColor = Color.white.opacity(0.85)
        t.codeBackground = Color.black.opacity(0.25)
        t.codeHeaderBackground = Color.black.opacity(0.35)
        t.inlineCodeBackground = Color.black.opacity(0.25)
        t.blockquoteRuleColor = Color.white.opacity(0.6)
        t.tableBorderColor = Color.white.opacity(0.5)
        t.horizontalRuleColor = Color.white.opacity(0.4)
        return t
    }()

    public static let pdfLight: ChatMarkdownTheme = {
        var t = ChatMarkdownTheme()
        t.textColor = .black
        t.secondaryTextColor = Color(white: 0.3)
        t.linkColor = Color(red: 0.0, green: 0.32, blue: 0.78)
        t.codeBackground = Color(white: 0.95)
        t.codeHeaderBackground = Color(white: 0.88)
        t.inlineCodeBackground = Color(white: 0.92)
        t.blockquoteRuleColor = Color(white: 0.6)
        t.tableBorderColor = Color(white: 0.55)
        t.horizontalRuleColor = Color(white: 0.6)
        t.syntaxColors = .pdfLight
        return t
    }()

    public static func forRole(_ role: MessageRole) -> ChatMarkdownTheme {
        switch role {
        case .user: return .user
        case .assistant: return .assistant
        }
    }
}
