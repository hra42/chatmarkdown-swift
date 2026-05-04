import SwiftUI

public struct ChatMarkdownCodeBlockConfiguration: Sendable {
    public let language: String?
    public let code: String
    public let isClosed: Bool
}

public protocol ChatMarkdownCodeBlockStyle: Sendable {
    associatedtype Body: View
    @ViewBuilder func makeBody(configuration: ChatMarkdownCodeBlockConfiguration) -> Body
}

public struct AnyChatMarkdownCodeBlockStyle: ChatMarkdownCodeBlockStyle, @unchecked Sendable {
    private let _makeBody: @Sendable (ChatMarkdownCodeBlockConfiguration) -> AnyView

    public init<S: ChatMarkdownCodeBlockStyle>(_ style: S) {
        self._makeBody = { config in AnyView(style.makeBody(configuration: config)) }
    }

    public func makeBody(configuration: ChatMarkdownCodeBlockConfiguration) -> AnyView {
        _makeBody(configuration)
    }
}
