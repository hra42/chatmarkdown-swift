import SwiftUI

public struct DefaultChatMarkdownCodeBlockStyle: ChatMarkdownCodeBlockStyle {
    public init() {}

    public func makeBody(configuration: ChatMarkdownCodeBlockConfiguration) -> some View {
        DefaultCodeBlockBody(configuration: configuration)
    }
}

private struct DefaultCodeBlockBody: View {
    let configuration: ChatMarkdownCodeBlockConfiguration
    @Environment(\.chatMarkdownThemeOverride) private var themeOverride
    @State private var highlighted: AttributedString = AttributedString()
    @State private var highlightKey: String = ""

    private var theme: ChatMarkdownTheme {
        themeOverride ?? .assistant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            codeBody
        }
        .background(theme.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: configuration.code + "|" + (configuration.language ?? "")) {
            let result = SyntaxHighlighter.highlight(
                configuration.code,
                language: configuration.language,
                font: theme.codeFont,
                palette: theme.syntaxColors
            )
            await MainActor.run {
                highlighted = result
            }
        }
    }

    private var header: some View {
        HStack {
            Text(configuration.language?.lowercased() ?? "code")
                .font(.caption)
                .foregroundStyle(theme.secondaryTextColor)
            Spacer()
            if configuration.isClosed {
                CopyButton(text: configuration.code, theme: theme)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.codeHeaderBackground)
    }

    private var codeBody: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 0) {
                applySelection(Text(highlighted.characters.isEmpty ? AttributedString(configuration.code) : highlighted))
                    .font(theme.codeFont)
                    .frame(minWidth: 0, alignment: .leading)
                if !configuration.isClosed {
                    StreamingCaret()
                        .font(theme.codeFont)
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .padding(12)
        }
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

private struct StreamingCaret: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let on = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            Text("▍")
                .opacity(on ? 1 : 0)
        }
    }
}

private struct CopyButton: View {
    let text: String
    let theme: ChatMarkdownTheme
    @State private var copied = false

    var body: some View {
        Button {
            Pasteboard.copy(text)
            HapticFeedback.success()
            copied = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "Copied!" : "Copy")
            }
            .font(.caption)
            .foregroundStyle(theme.secondaryTextColor)
        }
        .buttonStyle(.plain)
    }
}
