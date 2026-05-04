import SwiftUI

struct CodeBlockView: View {
    let language: String?
    let code: String
    let isClosed: Bool

    @Environment(\.chatMarkdownCodeBlockStyleOverride) private var styleOverride

    var body: some View {
        let configuration = ChatMarkdownCodeBlockConfiguration(
            language: language,
            code: code,
            isClosed: isClosed
        )
        if let styleOverride {
            styleOverride.makeBody(configuration: configuration)
        } else {
            DefaultChatMarkdownCodeBlockStyle().makeBody(configuration: configuration)
        }
    }
}
