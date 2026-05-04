import Foundation

enum SwiftRules {
    static let rules: LanguageRules = LanguageRules.make([
        ("//[^\n]*", .comment, []),
        ("/\\*[\\s\\S]*?\\*/", .comment, []),
        ("\"(?:\\\\.|[^\"\\\\])*\"", .string, []),
        ("\\b(?:func|let|var|if|else|guard|return|for|while|in|switch|case|default|break|continue|do|try|catch|throw|throws|rethrows|class|struct|enum|protocol|extension|import|public|private|internal|fileprivate|open|static|final|lazy|weak|unowned|init|deinit|self|super|nil|true|false|as|is|where|associatedtype|typealias|inout|defer|repeat|async|await|actor|some|any|Self)\\b", .keyword, []),
        ("\\b[A-Z][A-Za-z0-9_]*\\b", .type, []),
        ("\\b(?:0x[0-9A-Fa-f_]+|[0-9][0-9_]*(?:\\.[0-9_]+)?(?:[eE][+-]?[0-9_]+)?)\\b", .number, []),
    ])
}
