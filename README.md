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

## Phase 1 status

Phase 1 ships only the parser and block model — no rendering yet. Rendering arrives in Phase 2.

```swift
import ChatMarkdown

let doc = ChatMarkdownDocument(markdown: "# Hello\n\nWorld")
for block in doc.blocks {
    print(block.contentHash)
}
```
