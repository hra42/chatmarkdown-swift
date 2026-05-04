import Foundation

struct Pattern {
    let regex: NSRegularExpression
    let token: TokenClass
}

struct LanguageRules {
    let patterns: [Pattern]

    static func make(_ specs: [(String, TokenClass, NSRegularExpression.Options)]) -> LanguageRules {
        let patterns: [Pattern] = specs.compactMap { pattern, token, options in
            guard let regex = RegexCache.shared.regex(pattern, options: options) else {
                return nil
            }
            return Pattern(regex: regex, token: token)
        }
        return LanguageRules(patterns: patterns)
    }
}
