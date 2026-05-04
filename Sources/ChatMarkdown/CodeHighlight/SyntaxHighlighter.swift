import Foundation
import SwiftUI

public enum SyntaxHighlighter {
    static func rules(for language: String?) -> LanguageRules {
        switch language?.lowercased() {
        case "swift": return SwiftRules.rules
        case "py", "python": return PythonRules.rules
        case "js", "javascript", "ts", "typescript": return JavaScriptRules.rules
        case "json": return JSONRules.rules
        case "sh", "bash", "shell", "zsh": return BashRules.rules
        default: return GenericRules.rules
        }
    }

    /// Returns an array of (range, TokenClass) classifications for `code`.
    /// First-match-wins: comments and strings are applied first, so keywords inside them won't be highlighted.
    /// Ranges are NSRange (UTF-16) into the input string.
    public static func tokenize(_ code: String, language: String?) -> [(NSRange, TokenClass)] {
        let ns = code as NSString
        let length = ns.length
        guard length > 0 else { return [] }

        var marks: [TokenClass?] = Array(repeating: nil, count: length)
        let fullRange = NSRange(location: 0, length: length)
        let rules = self.rules(for: language)

        for pattern in rules.patterns {
            let matches = pattern.regex.matches(in: code, options: [], range: fullRange)
            for match in matches {
                let r = match.range
                guard r.location != NSNotFound else { continue }
                // Only fill slots not yet claimed
                var allFree = true
                for i in r.location..<(r.location + r.length) {
                    if marks[i] != nil { allFree = false; break }
                }
                if !allFree { continue }
                for i in r.location..<(r.location + r.length) {
                    marks[i] = pattern.token
                }
            }
        }

        // Coalesce equal-class runs
        var result: [(NSRange, TokenClass)] = []
        var i = 0
        while i < length {
            let cls = marks[i] ?? .plain
            var j = i + 1
            while j < length && (marks[j] ?? .plain) == cls {
                j += 1
            }
            result.append((NSRange(location: i, length: j - i), cls))
            i = j
        }
        return result
    }

    public static func highlight(
        _ code: String,
        language: String?,
        font: Font,
        palette: SyntaxPalette
    ) -> AttributedString {
        let ns = code as NSString
        let tokens = tokenize(code, language: language)
        var result = AttributedString()
        for (range, cls) in tokens {
            let segment = ns.substring(with: range)
            var part = AttributedString(segment)
            part.font = font
            part.foregroundColor = palette.color(for: cls)
            result.append(part)
        }
        return result
    }
}
