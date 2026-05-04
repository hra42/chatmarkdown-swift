import SwiftUI

struct HorizontalRuleView: View {
    let theme: ChatMarkdownTheme

    var body: some View {
        Rectangle()
            .fill(theme.horizontalRuleColor)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}
