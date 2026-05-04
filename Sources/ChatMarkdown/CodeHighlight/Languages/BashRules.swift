import Foundation

enum BashRules {
    static let rules: LanguageRules = LanguageRules.make([
        ("#[^\n]*", .comment, []),
        ("\"(?:\\\\.|[^\"\\\\])*\"", .string, []),
        ("'(?:\\\\.|[^'\\\\])*'", .string, []),
        ("\\b(?:if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|break|continue|export|local|readonly|declare|unset|source|alias|trap|exit|true|false)\\b", .keyword, []),
        ("\\$[A-Za-z_][A-Za-z0-9_]*", .type, []),
        ("\\b[0-9]+\\b", .number, []),
    ])
}
