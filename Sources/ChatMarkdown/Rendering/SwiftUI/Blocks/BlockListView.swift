import SwiftUI

struct BlockListView: View {
    let blocks: [ChatMarkdownBlock]
    let theme: ChatMarkdownTheme

    var body: some View {
        let ids = BlockIDSequence.make(blocks)
        VStack(alignment: .leading, spacing: theme.blockSpacing) {
            ForEach(Array(zip(ids, blocks)), id: \.0.fingerprint) { pair, block in
                _DebugCountingWrapper(fingerprint: pair.fingerprint) {
                    view(for: block)
                }
            }
        }
    }

    @ViewBuilder
    private func view(for block: ChatMarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let inlines):
            HeadingBlockView(level: level, inlines: inlines, theme: theme)
        case .paragraph(let inlines):
            ParagraphBlockView(inlines: inlines, theme: theme)
        case .codeBlock(let language, let code, let isClosed):
            CodeBlockView(language: language, code: code, isClosed: isClosed)
        case .unorderedList(let items):
            ListBlockView(kind: .unordered, items: items, theme: theme)
        case .orderedList(let start, let items):
            ListBlockView(kind: .ordered(start: start), items: items, theme: theme)
        case .blockquote(let inner):
            BlockquoteView(blocks: inner, theme: theme)
        case .table(let headers, let rows, let alignments):
            TableBlockView(headers: headers, rows: rows, alignments: alignments, theme: theme)
        case .horizontalRule:
            HorizontalRuleView(theme: theme)
        }
    }
}
