import Foundation

enum GenericRules {
    static let rules: LanguageRules = LanguageRules.make([
        ("//[^\n]*", .comment, []),
        ("#[^\n]*", .comment, []),
        ("\"(?:\\\\.|[^\"\\\\])*\"", .string, []),
        ("\\b(?:0x[0-9A-Fa-f]+|[0-9]+(?:\\.[0-9]+)?)\\b", .number, []),
    ])
}
