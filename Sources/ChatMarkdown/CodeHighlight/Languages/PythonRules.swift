import Foundation

enum PythonRules {
    static let rules: LanguageRules = LanguageRules.make([
        ("#[^\n]*", .comment, []),
        ("\"\"\"[\\s\\S]*?\"\"\"", .string, []),
        ("'''[\\s\\S]*?'''", .string, []),
        ("\"(?:\\\\.|[^\"\\\\])*\"", .string, []),
        ("'(?:\\\\.|[^'\\\\])*'", .string, []),
        ("\\b(?:def|class|if|elif|else|for|while|in|return|yield|import|from|as|pass|break|continue|try|except|finally|raise|with|lambda|global|nonlocal|None|True|False|and|or|not|is|async|await)\\b", .keyword, []),
        ("\\b[A-Z][A-Za-z0-9_]*\\b", .type, []),
        ("\\b(?:0x[0-9A-Fa-f_]+|[0-9][0-9_]*(?:\\.[0-9_]+)?(?:[eE][+-]?[0-9_]+)?)\\b", .number, []),
    ])
}
