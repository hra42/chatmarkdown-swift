import SwiftUI

struct ListBlockView: View {
    enum Kind {
        case unordered
        case ordered(start: Int)
    }

    let kind: Kind
    let items: [[ChatMarkdownBlock]]
    let theme: ChatMarkdownTheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.blockSpacing / 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(marker(for: index))
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.secondaryTextColor)
                        .frame(minWidth: 18, alignment: .trailing)
                    BlockListView(blocks: item, theme: theme)
                }
                .padding(.leading, theme.listIndent)
            }
        }
    }

    private func marker(for index: Int) -> String {
        switch kind {
        case .unordered:
            return "•"
        case .ordered(let start):
            return "\(start + index)."
        }
    }
}
