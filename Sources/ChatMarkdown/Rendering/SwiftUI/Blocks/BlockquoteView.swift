import SwiftUI

struct BlockquoteView: View {
    let blocks: [ChatMarkdownBlock]
    let theme: ChatMarkdownTheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(theme.blockquoteRuleColor)
                .frame(width: 3)
            BlockListView(blocks: blocks, theme: theme)
                .foregroundStyle(theme.secondaryTextColor)
        }
    }
}
