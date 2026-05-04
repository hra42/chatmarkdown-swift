import SwiftUI

public struct ChatMarkdownTableConfiguration: Sendable {
    public let headers: [AttributedString]
    public let rows: [[AttributedString]]
    public let alignments: [TableAlignment]
}

public protocol ChatMarkdownTableStyle: Sendable {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: ChatMarkdownTableConfiguration) -> Body
}

public struct AnyChatMarkdownTableStyle: ChatMarkdownTableStyle, @unchecked Sendable {
    private let _makeBody: @Sendable (ChatMarkdownTableConfiguration) -> AnyView

    public init<S: ChatMarkdownTableStyle>(_ style: S) {
        self._makeBody = { config in AnyView(style.makeBody(configuration: config)) }
    }

    public func makeBody(configuration: ChatMarkdownTableConfiguration) -> AnyView {
        _makeBody(configuration)
    }
}
