import Foundation

enum JSONRules {
    static let rules: LanguageRules = LanguageRules.make([
        ("\"(?:\\\\.|[^\"\\\\])*\"", .string, []),
        ("\\b(?:true|false|null)\\b", .keyword, []),
        ("-?\\b[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\\b", .number, []),
    ])
}
