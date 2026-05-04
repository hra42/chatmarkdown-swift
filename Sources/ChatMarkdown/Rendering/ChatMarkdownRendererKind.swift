import SwiftUI

/// Selects which renderer `ChatMarkdownView` uses to display a document.
///
/// `.textKit` is the default. It renders the entire message into a single
/// `NSTextView`/`UITextView`, enabling drag-selection across paragraphs,
/// lists, blockquotes, and code blocks. `.swiftUI` is preserved as a
/// fallback that composes each block as a separate SwiftUI view; selection
/// is per-block in that mode. On platforms without AppKit/UIKit (e.g.
/// Linux), the SwiftUI renderer is always used regardless of this value.
public enum ChatMarkdownRendererKind: Sendable, Hashable {
    /// TextKit-backed renderer. Default. Supports cross-block text selection.
    case textKit
    /// Per-block SwiftUI renderer. Selection is limited to a single block.
    case swiftUI
}

private struct ChatMarkdownRendererKindKey: EnvironmentKey {
    static let defaultValue: ChatMarkdownRendererKind = .textKit
}

extension EnvironmentValues {
    var chatMarkdownRendererKind: ChatMarkdownRendererKind {
        get { self[ChatMarkdownRendererKindKey.self] }
        set { self[ChatMarkdownRendererKindKey.self] = newValue }
    }
}

extension View {
    /// Selects the renderer used by `ChatMarkdownView` in this view subtree.
    ///
    /// The default is `.textKit`. Pass `.swiftUI` to opt into the legacy
    /// per-block SwiftUI renderer (useful for debugging or when the TextKit
    /// renderer is unsuitable for a given context).
    public func chatMarkdownRenderer(_ kind: ChatMarkdownRendererKind) -> some View {
        environment(\.chatMarkdownRendererKind, kind)
    }
}
