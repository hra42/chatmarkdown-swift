import SwiftUI

private struct ChatMarkdownThemeKey: EnvironmentKey {
    static let defaultValue: ChatMarkdownTheme? = nil
}

private struct ChatMarkdownCodeBlockStyleKey: EnvironmentKey {
    static let defaultValue: AnyChatMarkdownCodeBlockStyle? = nil
}

private struct ChatMarkdownTableStyleKey: EnvironmentKey {
    static let defaultValue: AnyChatMarkdownTableStyle? = nil
}

extension EnvironmentValues {
    var chatMarkdownThemeOverride: ChatMarkdownTheme? {
        get { self[ChatMarkdownThemeKey.self] }
        set { self[ChatMarkdownThemeKey.self] = newValue }
    }

    var chatMarkdownCodeBlockStyleOverride: AnyChatMarkdownCodeBlockStyle? {
        get { self[ChatMarkdownCodeBlockStyleKey.self] }
        set { self[ChatMarkdownCodeBlockStyleKey.self] = newValue }
    }

    var chatMarkdownTableStyleOverride: AnyChatMarkdownTableStyle? {
        get { self[ChatMarkdownTableStyleKey.self] }
        set { self[ChatMarkdownTableStyleKey.self] = newValue }
    }
}

extension View {
    public func chatMarkdownTheme(_ theme: ChatMarkdownTheme) -> some View {
        environment(\.chatMarkdownThemeOverride, theme)
    }

    public func chatMarkdownCodeBlockStyle<S: ChatMarkdownCodeBlockStyle>(_ style: S) -> some View {
        environment(\.chatMarkdownCodeBlockStyleOverride, AnyChatMarkdownCodeBlockStyle(style))
    }

    public func chatMarkdownTableStyle<S: ChatMarkdownTableStyle>(_ style: S) -> some View {
        environment(\.chatMarkdownTableStyleOverride, AnyChatMarkdownTableStyle(style))
    }
}
