import Foundation

public struct PlainTextOptions: Sendable {
    public enum CodeBlockHandling: Sendable, Equatable {
        case drop
        case marker(String)
        case keepText
    }

    public enum ListMarkerStyle: Sendable, Equatable {
        case none
        case bullet
        case ordinal
    }

    public enum LinkRendering: Sendable, Equatable {
        case textOnly
        case textThenURL
    }

    public var codeBlockHandling: CodeBlockHandling
    public var listMarkerStyle: ListMarkerStyle
    public var linkRendering: LinkRendering
    public var paragraphSeparator: String

    public init(
        codeBlockHandling: CodeBlockHandling = .marker("[code block]"),
        listMarkerStyle: ListMarkerStyle = .none,
        linkRendering: LinkRendering = .textOnly,
        paragraphSeparator: String = "\n\n"
    ) {
        self.codeBlockHandling = codeBlockHandling
        self.listMarkerStyle = listMarkerStyle
        self.linkRendering = linkRendering
        self.paragraphSeparator = paragraphSeparator
    }

    public static let ttsDefaults = PlainTextOptions()

    public static let faithful = PlainTextOptions(
        codeBlockHandling: .keepText,
        listMarkerStyle: .bullet,
        linkRendering: .textThenURL,
        paragraphSeparator: "\n\n"
    )
}
