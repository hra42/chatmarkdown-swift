# chatmarkdown-swift

A SwiftUI Markdown rendering library purpose-built for AI chat interfaces. Not a general-purpose CommonMark renderer — a focused tool for the shape of Markdown that LLMs actually produce, with first-class support for token-by-token streaming, copy-friendly code blocks, and theme integration that fits chat-bubble UIs.

The supported syntax subset and streaming semantics are documented in [SPEC.md](SPEC.md).

## Status

Experimental. No semantic versioning, no release tags, no support promise. `main` is the contract. The library is extracted from a single consumer (AI Hub) and evolves in lockstep with it.

## Installation

```swift
.package(url: "https://github.com/hra42/chatmarkdown-swift", branch: "main")
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ChatMarkdown", package: "chatmarkdown-swift"),
    ]
)
```

## Status

Phase 2 (current): SwiftUI rendering of all supported features. Streaming-aware view-identity reuse arrives in Phase 3.

## Usage

```swift
import SwiftUI
import ChatMarkdown

struct MessageView: View {
    let markdown: String
    let role: MessageRole

    var body: some View {
        ChatMarkdownView(markdown, role: role)
    }
}
```

### Theming

Themes are value-type structs. Built-in presets: `.assistant`, `.user`, `.pdfLight`. Pass a custom theme via `.chatMarkdownTheme(_:)`.

```swift
var theme = ChatMarkdownTheme.assistant
theme.linkColor = .pink
theme.linksUnderlined = false

ChatMarkdownView(markdown)
    .chatMarkdownTheme(theme)
```

### Custom code-block style

```swift
struct PlainCodeBlockStyle: ChatMarkdownCodeBlockStyle {
    func makeBody(configuration: ChatMarkdownCodeBlockConfiguration) -> some View {
        Text(configuration.code)
            .font(.system(.body, design: .monospaced))
            .padding()
            .background(.gray.opacity(0.15))
    }
}

ChatMarkdownView(markdown)
    .chatMarkdownCodeBlockStyle(PlainCodeBlockStyle())
```

### Parsing only

If you only need the AST (for example, to drive a custom renderer), use `ChatMarkdownDocument` directly:

```swift
let doc = ChatMarkdownDocument(markdown: "# Hello\n\nWorld")
for block in doc.blocks {
    print(block.contentHash)
}
```
