import SwiftUI

struct HeadingBlockView: View {
    let level: Int
    let inlines: [ChatMarkdownInline]
    let theme: ChatMarkdownTheme

    var body: some View {
        let clamped = max(1, min(level, 6))
        let font = theme.headingFonts[clamped] ?? theme.bodyFont
        let attributed = InlineAttributedStringBuilder.build(inlines, theme: theme, baseFont: font)
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
