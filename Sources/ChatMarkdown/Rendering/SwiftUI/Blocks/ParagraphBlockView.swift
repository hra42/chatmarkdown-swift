import SwiftUI

struct ParagraphBlockView: View {
    let inlines: [ChatMarkdownInline]
    let theme: ChatMarkdownTheme

    var body: some View {
        let attributed = InlineAttributedStringBuilder.build(inlines, theme: theme, baseFont: theme.bodyFont)
        applySelection(Text(attributed))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func applySelection(_ text: Text) -> some View {
        if theme.textSelectionEnabled {
            text.textSelection(.enabled)
        } else {
            text.textSelection(.disabled)
        }
    }
}
