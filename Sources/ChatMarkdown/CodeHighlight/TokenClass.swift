import SwiftUI

public enum TokenClass: Sendable, Hashable {
    case keyword
    case string
    case comment
    case number
    case type
    case plain
}

extension SyntaxPalette {
    func color(for token: TokenClass) -> Color {
        switch token {
        case .keyword: return keyword
        case .string: return string
        case .comment: return comment
        case .number: return number
        case .type: return type
        case .plain: return plain
        }
    }
}
