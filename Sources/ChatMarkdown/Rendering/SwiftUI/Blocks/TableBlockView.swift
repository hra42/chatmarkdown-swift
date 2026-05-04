import SwiftUI

struct TableBlockView: View {
    let headers: [[ChatMarkdownInline]]
    let rows: [[[ChatMarkdownInline]]]
    let alignments: [TableAlignment]
    let theme: ChatMarkdownTheme

    @Environment(\.chatMarkdownTableStyleOverride) private var styleOverride

    var body: some View {
        let renderedHeaders = headers.map {
            InlineAttributedStringBuilder.build($0, theme: theme, baseFont: theme.bodyFont)
        }
        let renderedRows = rows.map { row in
            row.map {
                InlineAttributedStringBuilder.build($0, theme: theme, baseFont: theme.bodyFont)
            }
        }
        let configuration = ChatMarkdownTableConfiguration(
            headers: renderedHeaders,
            rows: renderedRows,
            alignments: alignments
        )

        if let styleOverride {
            styleOverride.makeBody(configuration: configuration)
        } else {
            DefaultChatMarkdownTableStyle().makeBody(configuration: configuration)
        }
    }
}
