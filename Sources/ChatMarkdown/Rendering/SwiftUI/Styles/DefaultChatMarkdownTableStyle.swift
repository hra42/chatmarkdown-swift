import SwiftUI

public struct DefaultChatMarkdownTableStyle: ChatMarkdownTableStyle {
    public init() {}

    public func makeBody(configuration: ChatMarkdownTableConfiguration) -> some View {
        DefaultTableBody(configuration: configuration)
    }
}

private struct DefaultTableBody: View {
    let configuration: ChatMarkdownTableConfiguration
    @Environment(\.chatMarkdownThemeOverride) private var themeOverride

    private var theme: ChatMarkdownTheme {
        themeOverride ?? .assistant
    }

    private func alignment(for column: Int) -> HorizontalAlignment {
        guard column < configuration.alignments.count else { return .leading }
        switch configuration.alignments[column] {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func textAlignment(for column: Int) -> TextAlignment {
        guard column < configuration.alignments.count else { return .leading }
        switch configuration.alignments[column] {
        case .left, .none: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Rectangle()
                    .fill(theme.tableBorderColor)
                    .frame(height: 1)
                ForEach(Array(configuration.rows.enumerated()), id: \.offset) { _, row in
                    bodyRow(row)
                    Rectangle()
                        .fill(theme.tableBorderColor.opacity(0.4))
                        .frame(height: 1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.tableBorderColor, lineWidth: 1)
            )
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(configuration.headers.enumerated()), id: \.offset) { col, header in
                Text(header)
                    .font(theme.bodyFont.bold())
                    .multilineTextAlignment(textAlignment(for: col))
                    .frame(maxWidth: .infinity, alignment: alignment(for: col).asAlignment)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                if col < configuration.headers.count - 1 {
                    Rectangle()
                        .fill(theme.tableBorderColor.opacity(0.4))
                        .frame(width: 1)
                }
            }
        }
    }

    private func bodyRow(_ row: [AttributedString]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { col, cell in
                Text(cell)
                    .font(theme.bodyFont)
                    .multilineTextAlignment(textAlignment(for: col))
                    .frame(maxWidth: .infinity, alignment: alignment(for: col).asAlignment)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                if col < row.count - 1 {
                    Rectangle()
                        .fill(theme.tableBorderColor.opacity(0.4))
                        .frame(width: 1)
                }
            }
        }
    }
}

private extension HorizontalAlignment {
    var asAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}
