import Foundation

enum JavaScriptRules {
    static let rules: LanguageRules = LanguageRules.make([
        ("//[^\n]*", .comment, []),
        ("/\\*[\\s\\S]*?\\*/", .comment, []),
        ("\"(?:\\\\.|[^\"\\\\])*\"", .string, []),
        ("'(?:\\\\.|[^'\\\\])*'", .string, []),
        ("`(?:\\\\.|[^`\\\\])*`", .string, []),
        ("\\b(?:var|let|const|function|return|if|else|for|while|do|switch|case|default|break|continue|new|this|class|extends|super|import|export|from|as|default|async|await|try|catch|finally|throw|typeof|instanceof|in|of|delete|void|null|undefined|true|false|interface|type|enum|implements|public|private|protected|readonly|static|abstract|namespace|declare|keyof|infer|never|unknown|any)\\b", .keyword, []),
        ("\\b[A-Z][A-Za-z0-9_]*\\b", .type, []),
        ("\\b(?:0x[0-9A-Fa-f_]+|[0-9][0-9_]*(?:\\.[0-9_]+)?(?:[eE][+-]?[0-9_]+)?)\\b", .number, []),
    ])
}
