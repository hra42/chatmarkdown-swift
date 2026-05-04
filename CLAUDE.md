# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                                       # build library
swift test                                        # run all tests
swift test --filter <TestSuite>                   # run one suite, e.g. TextKitOverlayTests
swift test --filter <TestSuite>/<testMethod>      # run a single test
REGEN_FIXTURES=1 swift test --filter FixtureGenerator                      # regenerate JSON fixtures after intentional model changes
REGEN_FIXTURES=1 swift test --filter TextKitFixturesConformanceTests       # regenerate the TextKit storage-contract fixtures
```

There is no separate lint step — Swift 6 strict concurrency is enforced by the compiler (see `Package.swift`).

## Architecture

The library is a streaming-aware Markdown renderer for LLM chat output. Read `SPEC.md` first — it pins the supported syntax subset, the streaming invariants, and the TextKit storage attribute contract. Treat SPEC.md as the source of truth for cross-port behavior, not a description of the implementation.

### Pipeline

```
markdown string
  → ChatMarkdownDocument             (Document/ — parse + normalize via swift-markdown)
  → [ChatMarkdownBlock]              (Document/ChatMarkdownBlock.swift — the AST is the IR)
  → BlockIDSequence                  (Streaming/ — content-addressed identity per block)
  → renderer                         (Rendering/SwiftUI or Rendering/TextKit, selected by env)
```

`ChatMarkdownBlock` and `ChatMarkdownInline` are the canonical IR. Every renderer (SwiftUI, TextKit, HTML, PlainText) consumes the same `[ChatMarkdownBlock]`. New output formats hang off this layer; do not bypass it.

### Streaming identity

`BlockID = (contentHash: UInt64, occurrenceIndex: Int)` collapsed into a single `fingerprint: UInt64` (FNV-1a). The fingerprint is what SwiftUI's `ForEach(id:)` and the TextKit incremental updater key on. Fixture-validated invariant: between any two consecutive snapshots where the new input is a strict suffix-extension, all but possibly the trailing block keep their fingerprint. Breaking this invariant breaks streaming performance.

The `FenceParityScanner` is a separate line-level pre-pass over raw markdown that detects an open fenced code region; it overrides `isClosed` on the trailing `.codeBlock` because Apple's `swift-markdown` silently closes open fences.

### Renderer selection

`Rendering/ChatMarkdownRendererKind.swift` is an environment-keyed selector, `.textKit` (default) or `.swiftUI`. The TextKit renderer flattens the document to a single `NSAttributedString` so users can drag-select across the whole message. The SwiftUI renderer composes one view per block — selection limited to a single block.

### TextKit renderer specifics

This is the most subtle part of the codebase. Key invariants are documented inline in the files; the points below are the ones that bite if you don't already know them.

**TextKit 1 is required, and not the default.** Modern `NSTextView` and `UITextView` use TextKit 2 by default and silently route around the legacy attachment APIs. `ChatMarkdownNSTextView` and `ChatMarkdownUITextView` opt out at construction (`init(usingTextLayoutManager: false)`) and override `init(frame:)` to keep that opt-out for any future test that reaches for the old initializer. **Do not remove these convenience inits and do not switch to TextKit 2 without replacing the attachment-sizing path.**

**Attachment sizing is platform-split.** The plan agent's intuition (and Apple's iOS-first docs) suggest `NSTextAttachment.attachmentBounds(for:proposedLineFragment:glyphPosition:characterIndex:)` is the universal entry point. It is not.

- **AppKit (macOS)**: `NSLayoutManager` queries the attachment via `NSTextAttachmentCellProtocol.cellFrame(for:proposedLineFragment:glyphPosition:characterIndex:)` and never calls `attachmentBounds`. `ChatMarkdownTableAttachment` therefore installs a `ChatMarkdownTableAttachmentCell` on macOS; the cell delegates back to the attachment's shared `computeBounds(containerWidth:lineFrag:)`.
- **UIKit (iOS / visionOS)**: TextKit 1 calls `attachmentBounds(...)` directly, so the override is the entry point on that side.

If a future change moves to TextKit 2 or migrates to `NSTextAttachmentViewProvider`, both the cell and the override must be replaced together. Verifying with a standalone probe (small `NSTextStorage` + `NSLayoutManager` + custom attachment) is the fastest way to confirm which path actually runs on the current SDK — doing it through `NSTextView` hides whether TextKit 2 is silently substituting.

**The storage attribute contract is in SPEC.md.** Treat the keys (`.chatMarkdownAttachmentSlot`, `.chatMarkdownBlockKind`, …) as a public surface. The TextKit conformance fixtures (`Tests/ChatMarkdownTests/Fixtures/textkit/*.textkit.json`) pin them — regenerate intentionally with `REGEN_FIXTURES=1 swift test --filter TextKitFixturesConformanceTests` when the builder output legitimately changes.

> **Doc divergence to be aware of:** SPEC.md still describes table attachment slots as `1 + (header ? 1 : 0) + rowCount` characters. As of the bug-2 fix, table slots are a single `\u{FFFC}` character; vertical space is reserved by the attachment-bounds / cell-frame path described above. The textkit fixtures reflect the new shape; SPEC.md does not. If you touch this area, update SPEC.md to match.

**Incremental updates.** `ChatMarkdownIncrementalUpdater` diffs by `BlockID.fingerprint` (longest common prefix), then performs one `replaceCharacters(in:with:)` on the diverging tail. A stable table block's attachment instance therefore survives across `apply()` calls — the per-instance height cache stays valid. The host re-injects current `theme` / `tableStyle` references on every `apply()` (cheap), and `relayoutChatMarkdownOverlays()` clears that cache and `invalidateLayout(forCharacterRange:)`s the table ranges when the container width has changed. If you add new mutable attachment state, follow the same pattern (clear-on-width-change, reset on `apply()` if the SwiftUI tree depends on it).

### Theme and styles

`ChatMarkdownTheme` is a value type. `AnyChatMarkdownCodeBlockStyle` / `AnyChatMarkdownTableStyle` are type-erased style protocols flowing through SwiftUI environment values (`Theme/EnvironmentValues+ChatMarkdown.swift`). The TextKit renderer reads them per `apply()` and feeds the same SwiftUI tree both into the overlay manager (visible rendering) and into the attachment (height measurement) via `ChatMarkdownOverlayRoot.makeView(...)`. Diverging those two callers produces incorrect overlay sizing.

### Tests

- Block-level / parser tests use the JSON fixtures in `Tests/ChatMarkdownTests/Fixtures/*.expected.json`. Conformance is "produces equivalent JSON for every fixture."
- Streaming behavior is tested by `Tests/ChatMarkdownTests/Fixtures/streaming/*.json` — each step has an input + expected `blockIDs`. `stableBlockCount` is derived from the previous step's IDs; only edit the `input` strings by hand and regenerate.
- TextKit conformance is in `Tests/ChatMarkdownTests/Fixtures/textkit/*.textkit.json`.
- TextKit layout tests (e.g. attachment height) construct a `ChatMarkdownNSTextView` directly. They must set `view.textContainer?.size = NSSize(width: ..., height: .greatestFiniteMagnitude)` explicitly — `widthTracksTextView` does not propagate without a window, so the textContainer width otherwise stays at 0 and the attachment falls back to a placeholder. See `TextKitOverlayTests.testTableAttachmentReservesHeightBeyondNaiveLineCount` for the canonical pattern.

## Status

Per README: experimental, no semver, no release tags. `main` is the contract. Ports (rust / ts) are planned and validate against the same fixtures — keep that in mind when changing the JSON fixture shape or the `BlockID` algorithm.
