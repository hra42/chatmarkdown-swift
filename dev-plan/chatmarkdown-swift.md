# chatmarkdown-swift — Implementation Plan

---

## Overview

`chatmarkdown-swift` is a SwiftUI Markdown rendering library purpose-built for AI chat interfaces. It is **not** a general-purpose CommonMark renderer — it is a focused tool optimized for the specific shape of Markdown that LLMs produce, with first-class support for token-by-token streaming, copy-friendly code blocks, and theme integration that fits chat-bubble UIs.

The library is extracted from AI Hub V2's chat rendering needs but designed as a standalone Swift Package. It will live at `github.com/hra42/chatmarkdown-swift` and be consumed by AI Hub via SPM. The `-swift` suffix leaves room for sibling implementations (`chatmarkdown-rust`, `chatmarkdown-ts`) sharing a common spec and test fixtures.

The project replaces AI Hub V2's current `MarkdownView` dependency, eliminating the `RangeAdjuster` crash workaround in `MarkdownContentView.swift`, consolidating the duplicate PDF rendering path, and unlocking incremental rendering during SSE streaming — the single biggest UX win.

---

## Why Build This (and Not Use an Existing Library)

The existing options each fail in a way that matters for AI chat:

- **`Text(.init(markdown:))`** — only inline formatting; no headings, lists, code blocks, tables.
- **`MarkdownUI`** — full-featured but re-parses the entire document on every text mutation; visible flicker during SSE streaming. No incremental rendering.
- **`MarkdownView`** (current dependency) — relies on `swift-markdown` whose `RangeAdjuster` crashes on tab + block-directive combinations, forcing a sanitization pre-pass on every render. Custom code-block styling requires significant boilerplate (see `CopyableCodeBlockView` in `MarkdownContentView.swift:90-296`).
- **`Down`, `Splash`** — lightly maintained; Swift 6 / visionOS 26 compatibility is uncertain.

We are already deep in "patching the library" territory. The remaining value of an external lib is just the parser — and Apple's `swift-markdown` provides that cleanly. Building our own renderer on top is the smallest delta with the largest control gain.

---

## Goals

1. **Streaming-first rendering.** Token-by-token updates from SSE must not re-parse or re-render unchanged content. Stable blocks above the cursor stay mounted.
2. **Feature parity** with everything AI Hub renders today (see Current Feature Inventory below).
3. **One AST, multiple renderers.** Same parsed document drives the SwiftUI chat renderer, the `AttributedString` renderer (PDF/RTF copy/TTS), and an HTML renderer (rich-text clipboard) — eliminating the current duplicate `PDFMarkdownContentView` and `MarkdownToRTFService` paths.
4. **Theme integration that fits chat bubbles.** First-class support for user-message vs. assistant-message styling, with no hardcoded colors in the library.
5. **Zero crashes on real LLM output.** Including malformed/unfinished Markdown that appears mid-stream (unclosed code fences, dangling list markers, partial tables).

---

## Current Feature Inventory

Everything AI Hub V2 currently renders — extracted from `MarkdownContentView.swift`, `PDFMessageView.swift`, `MarkdownToRTFService.swift`, `TextToSpeechService.swift`. The library MUST cover all of these from Phase 2 onward.

### Block-level features (in use today)

| Feature                   | Where it's used                           | Notes                                                                     |
| ------------------------- | ----------------------------------------- | ------------------------------------------------------------------------- |
| Headings H1–H4            | Chat (`.font(…, for: .h1/.h2/.h3/.h4)`)   | Distinct font sizes per level; H5/H6 must parse without breaking          |
| Paragraphs                | Chat, PDF, RTF, HTML                      | Body font configurable per renderer                                       |
| Fenced code blocks        | Chat (`CopyableCodeBlockStyle`), PDF      | Language label, copy button (chat only), syntax highlighting (chat only)  |
| Inline code               | All renderers                             | Monospaced, separate font size from body                                  |
| Ordered & unordered lists | All renderers                             | Including nested lists                                                    |
| Blockquotes               | All renderers                             |                                                                           |
| Tables (GFM pipe syntax)  | Chat, PDF (`PDFTableStyle`), HTML, RTF    | PDF needs explicit grayscale colors (no `.quaternary` — `ImageRenderer` can't resolve it) |
| Horizontal rules          | All renderers                             |                                                                           |

### Inline features (in use today)

- Bold (`**`)
- Italic (`*`)
- Inline code (`` ` ``)
- Links (`[text](url)`) — clickable in chat (with `.tint()` color), styled in PDF, preserved in HTML/RTF
- Hard line breaks
- Underlined links in chat (`.underlineLinks()`)

### Renderer-level features (in use today)

| Feature                       | Current site                                        | New library equivalent                                |
| ----------------------------- | --------------------------------------------------- | ----------------------------------------------------- |
| Per-element font config       | `MarkdownContentView` `.font(…, for: .body/.h1/…)`  | `ChatMarkdownTheme` protocol with per-element fonts   |
| Foreground color override     | `.foregroundStyle(…)`                               | `ChatMarkdownTheme.textColor` + role-based override   |
| Link tint                     | `.tint(…)`                                          | `ChatMarkdownTheme.linkColor`                         |
| Underlined links              | `.underlineLinks()`                                 | Theme flag `linksUnderlined: Bool`                    |
| Custom code block style       | `CodeBlockStyle` (`CopyableCodeBlockStyle`)         | `ChatMarkdownCodeBlockStyle` protocol                 |
| Custom table style            | `MarkdownTableStyle` (`PDFTableStyle`)              | `ChatMarkdownTableStyle` protocol                     |
| Text selection                | `.textSelection(.enabled)`                          | Default-on; opt-out via theme                         |
| Custom font family (PDF)      | `Font.custom("Epilogue", size:)` via theme          | `ChatMarkdownTheme` accepts arbitrary `Font` values   |
| Force light-mode colors (PDF) | Hardcoded black/grayscale                           | `ChatMarkdownTheme.PDFLight` preset                   |

### Code-block specific features (in use today)

The current `CopyableCodeBlockView` in `MarkdownContentView.swift:90-296` ships:

- **Language label** in header (lowercased; falls back to `"code"`)
- **Copy button** with success animation (`Copied!` + checkmark for 2 seconds), haptic feedback, `NSPasteboard` / `UIPasteboard` cross-platform
- **Horizontal scroll** for long lines
- **Syntax highlighting** via cached `NSRegularExpression`s for: `swift`, `python`/`py`, `javascript`/`js`/`typescript`/`ts`, `json`, `bash`/`sh`/`shell`/`zsh`, plus a generic fallback. Token classes: keyword, string, comment, number, type
- **Color scheme awareness** — header & body backgrounds switch on `colorScheme`
- **Async highlight computation** via `.task(id:)` — re-highlights only when code text changes
- **Regex cache** keyed on pattern + options to avoid recompiling identical regexes across blocks

All of this must be reproducible in the new library — either as the default `ChatMarkdownCodeBlockStyle` or by injecting AI Hub's existing implementation through the protocol.

### Output formats (in use today)

| Format                | Source                          | Consumer                                  |
| --------------------- | ------------------------------- | ----------------------------------------- |
| SwiftUI views         | `MarkdownContentView`           | Live chat, message rows                   |
| SwiftUI views (PDF)   | `PDFMarkdownContentView`        | PDF export via `ImageRenderer`            |
| `NSAttributedString`  | `MarkdownToRTFService`          | Copy-as-rich-text (macOS pasteboard)      |
| HTML string           | `MarkdownToRTFService.html(_:)` | Copy-as-HTML (clipboard, has table support) |
| Plain text (stripped) | `TextToSpeechService`           | TTS playback — must strip code blocks, normalize lists |

The new library produces all five from a single parsed `ChatMarkdownDocument`. No more parallel parsing pipelines.

### Stability requirements (in use today)

- **Sanitization workaround** (`MarkdownContentView.sanitize(_:)`) — converts tabs to four spaces and normalizes `\r\n`/`\r` to `\n` to avoid a `swift-markdown` `RangeAdjuster` crash. The new library must handle these inputs natively (either by sanitizing internally or by avoiding the buggy code path) so the workaround can be deleted.
- **Empty-string handling** — `sanitize("")` returns `" "` to prevent downstream crashes. New library must accept empty input cleanly.

---

## Non-Goals

The `chatmarkdown` name licenses us to deliberately drop features that don't appear in real LLM output:

- Reference-style links (`[text][ref]` and `[ref]: url`)
- Setext headings (underline-style `===`, `---`)
- HTML inline and HTML blocks
- Footnotes
- Definition lists
- Complex image constructs (alt-text styling, title attributes)
- Custom block directives
- Math / LaTeX rendering (inline `$…$` or block `$$…$$`)

If a user pastes a document using these features, they will render as plain text. This is a feature, not a bug — it keeps the library small and the streaming path fast.

---

## Spec

A `SPEC.md` at the repo root will document the supported subset and streaming semantics, so future ports (`chatmarkdown-rust`, etc.) can match Swift's behavior. Highlights:

### Supported syntax

| Feature              | Syntax                           | Notes                                          |
| -------------------- | -------------------------------- | ---------------------------------------------- |
| ATX headings         | `# H1` … `#### H4`               | H5/H6 parsed but rendered as H4                |
| Bold                 | `**text**`                       | Underscores also accepted                      |
| Italic               | `*text*`                         | Underscores also accepted                      |
| Inline code          | `` `code` ``                     |                                                |
| Fenced code blocks   | ` ```lang\n…\n``` `              | Language label, copy button, syntax highlight |
| Unordered lists      | `- ` / `* `                      | Nested via indentation                         |
| Ordered lists        | `1. `                            | Nested via indentation                         |
| Blockquotes          | `> `                             | Nested allowed                                 |
| Links                | `[text](url)`                    | Inline only                                    |
| Tables               | GFM pipe syntax                  |                                                |
| Horizontal rule      | `---`                            |                                                |
| Hard break           | `\\\n` or two trailing spaces    |                                                |

### Streaming semantics

- A document is rendered as an ordered sequence of **blocks** (heading, paragraph, code block, list, etc.).
- During streaming, only the **trailing block** can change between renders. All preceding blocks are considered stable and reused.
- An **unclosed code fence** at end-of-stream renders as an in-progress code block with no closing styling — never as a paragraph.
- An **unclosed bold/italic span** at end-of-stream renders as plain text up to the cursor, then re-styles when closed.
- Hash-based block fingerprinting determines reuse: identical `(blockKind, contentHash)` → reuse view identity → SwiftUI skips re-layout.

### Test fixtures

`Tests/Fixtures/` will contain `.md` input files paired with `.expected.json` AST snapshots. These are language-agnostic and become the conformance suite for any future port.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  swift-markdown (Apple)                             │
│    ↓  parses CommonMark + GFM into Markup AST       │
└─────────────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────┐
│  ChatMarkdownDocument                               │
│    • Normalizes Markup AST → ChatMarkdownBlock[]    │
│    • Drops unsupported nodes (HTML, footnotes, …)   │
│    • Computes per-block content hash                │
│    • Diffs against previous document for streaming  │
└─────────────────────────────────────────────────────┘
                       ↓
        ┌──────────────┬───────────────┬───────────────┐
        ↓              ↓               ↓               ↓
┌──────────────┐ ┌────────────────┐ ┌──────────┐ ┌────────────┐
│ SwiftUI      │ │ AttributedStr. │ │ HTML     │ │ Plain text │
│ ChatMarkdown │ │ NSAttributed-  │ │ string   │ │ (TTS)      │
│ View         │ │ String / RTF   │ │ (clipbd.)│ │            │
└──────────────┘ └────────────────┘ └──────────┘ └────────────┘
```

### Public API surface (target)

```swift
// Primary entry point
public struct ChatMarkdownView: View {
    public init(_ markdown: String, role: MessageRole = .assistant)
}

// Theming
public protocol ChatMarkdownTheme {
    var bodyFont: Font { get }
    var headingFonts: [Int: Font] { get }
    var codeFont: Font { get }
    var textColor: Color { get }
    var linkColor: Color { get }
    var codeBackground: Color { get }
    // …
}

// Role-based styling for chat bubbles
public enum MessageRole { case user, assistant }

// Code block customization
public protocol ChatMarkdownCodeBlockStyle {
    associatedtype Body: View
    func makeBody(language: String?, code: String) -> Body
}

// AttributedString renderer for PDF/RTF
public enum ChatMarkdownAttributedRenderer {
    public static func render(_ markdown: String, theme: ChatMarkdownTheme) -> AttributedString
    public static func renderNS(_ markdown: String, theme: ChatMarkdownTheme) -> NSAttributedString
}

// HTML renderer for rich-text clipboard (table-friendly)
public enum ChatMarkdownHTMLRenderer {
    public static func render(_ markdown: String, embedStyles: Bool = true) -> String
}

// Plain-text renderer for TTS (strips code blocks, normalizes lists)
public enum ChatMarkdownPlainTextRenderer {
    public static func render(_ markdown: String, options: PlainTextOptions = .ttsDefaults) -> String
}

// Custom table style (parity with current MarkdownTableStyle)
public protocol ChatMarkdownTableStyle {
    associatedtype Body: View
    func makeBody(configuration: ChatMarkdownTableConfiguration) -> Body
}
```

### Repository layout

```
chatmarkdown-swift/
├── Package.swift
├── README.md
├── SPEC.md
├── Sources/
│   └── ChatMarkdown/
│       ├── Document/          # AST normalization, block model, hashing
│       ├── Streaming/         # Diff engine, stable-block detection
│       ├── Rendering/
│       │   ├── SwiftUI/       # ChatMarkdownView + per-block views
│       │   ├── AttributedString/  # NSAttributedString + AttributedString
│       │   ├── HTML/          # HTML string renderer for clipboard
│       │   └── PlainText/     # TTS-friendly text stripper
│       ├── Theme/             # ChatMarkdownTheme protocol + defaults + PDF light preset
│       └── CodeHighlight/     # Regex-based syntax highlighter (ported from CopyableCodeBlockView)
└── Tests/
    ├── ChatMarkdownTests/
    └── Fixtures/              # *.md + *.expected.json pairs
```

---

## Phases

### Phase 1 — Foundation: Repo, Parser Wrapper, Block Model

**Goal:** Empty package that parses Markdown into our normalized block model. No rendering yet.

- Create `github.com/hra42/chatmarkdown-swift` (public, no releases, no semver — `main` is the contract).
- `Package.swift` with `swift-markdown` dependency, `ChatMarkdown` library product, `ChatMarkdownTests` target.
- Define `ChatMarkdownBlock` enum (`heading`, `paragraph`, `codeBlock`, `unorderedList`, `orderedList`, `blockquote`, `table`, `horizontalRule`).
- Define `ChatMarkdownInline` enum (`text`, `bold`, `italic`, `code`, `link`, `lineBreak`).
- Implement `MarkupVisitor` that walks `swift-markdown`'s AST and produces `[ChatMarkdownBlock]`. Drop unsupported nodes silently.
- Implement `ChatMarkdownDocument` value type with `init(markdown: String)` and a `blocks` array.
- Per-block content hash (`Hasher`-based; stable across runs).
- README scaffold: scope statement, "experimental, no versioning, no support" disclaimer.
- `SPEC.md` first draft covering supported syntax table.
- Tests: parse all current `MarkdownSanitizationTests.swift` fixtures and confirm no crashes; snapshot a few representative documents to `Tests/Fixtures/`.

**Done when:** `swift test` passes locally; AI Hub can `import ChatMarkdown` via local path dependency and call `ChatMarkdownDocument(markdown: …).blocks` without errors.

---

### Phase 2 — SwiftUI Renderer (Non-Streaming Parity)

**Goal:** `ChatMarkdownView` renders all supported features at parity with current `MarkdownContentView`. No streaming optimization yet — re-render on every change is acceptable.

- `ChatMarkdownView: View` accepting `(String, MessageRole)`.
- One SwiftUI view per block kind: `HeadingBlockView`, `ParagraphBlockView`, `CodeBlockView`, `ListBlockView`, `BlockquoteView`, `TableBlockView`, `HorizontalRuleView`.
- Inline rendering via `AttributedString` composition (consolidates bold/italic/code/link in one `Text`).
- `ChatMarkdownTheme` protocol with a `DefaultChatMarkdownTheme` implementation. Per-element fonts (`bodyFont`, `headingFonts[1...6]`, `codeFont`), colors, link tint, link underline flag, custom font families (parity with current PDF `Font.custom("Epilogue", …)` usage).
- Built-in theme presets: `.assistant`, `.user`, `.pdfLight` (forces black text on white for `ImageRenderer` export — fixes the `.quaternary` color resolution issue noted in `PDFTableStyle`).
- Theme injection via `Environment`. `MessageRole` selects between `.userTheme` and `.assistantTheme`.
- Default code block: header with language label + copy button, syntax-highlighted body. Port the regex-based highlighter and regex cache from `MarkdownContentView.swift:107-280` verbatim — already cached and battle-tested. Ship with the same language coverage: `swift`, `python`/`py`, `javascript`/`js`/`typescript`/`ts`, `json`, `bash`/`sh`/`shell`/`zsh`, plus generic fallback.
- Copy button parity: `Copied!` confirmation, 2-second timeout, haptic feedback via `HapticFeedback.success()` (or equivalent abstraction in the lib), cross-platform pasteboard.
- `ChatMarkdownCodeBlockStyle` protocol so AI Hub (or anyone) can override the default.
- `ChatMarkdownTableStyle` protocol mirroring the current `MarkdownTableStyle` API, so `PDFTableStyle`-style overrides remain possible.
- Wire AI Hub's `MarkdownContentView` to use `ChatMarkdownView` behind a feature flag (`UserDefaults` key), keeping `MarkdownView` as fallback.
- Visual QA against every preview in `MarkdownContentView.swift:298-343`, the PDF preview in `PDFMessageView.swift:169-222`, and a real chat conversation with code, lists, tables.

**Done when:** Toggling the flag in AI Hub produces visually equivalent output; no regressions in PDF export path (still uses old `MarkdownView` for now); copy button works on macOS, iOS, visionOS.

---

### Phase 3 — Streaming-Optimized Rendering

**Goal:** The killer feature. Token-by-token streaming updates only the trailing block; preceding blocks stay mounted with stable view identity.

- `ChatMarkdownView` becomes streaming-aware: holds previous `ChatMarkdownDocument`, diffs blocks on update.
- Block diffing rule: blocks `[0..<n-1]` are considered stable if their content hashes match prefix of new document; trailing block always re-rendered.
- SwiftUI `id(_:)` modifier per block keyed on stable content hash → SwiftUI reuses view identity → no flicker, no re-layout for stable content.
- Special handling for **in-progress code blocks**: if last block is `codeBlock` and document ended without closing fence, render in "streaming" state (no copy button yet, optional cursor indicator).
- Special handling for **in-progress inline spans**: bold/italic with no closing marker rendered as plain text until close; closing token triggers re-style of trailing block only.
- Performance test harness: measure render count and frame time for a 50-block AI response streamed at 60 tokens/sec. Target: zero re-layouts for blocks 0..n-2.
- Real-world test: enable in AI Hub, run a long streaming chat with code-heavy response, observe in Instruments.

**Done when:** Streaming a long response in AI Hub shows visibly smoother rendering than current `MarkdownView`; Instruments confirms stable blocks are not re-laid out; no visual artifacts on fence close, list-item completion, or table-row append.

---

### Phase 4 — Non-SwiftUI Renderers + AI Hub Consolidation

**Goal:** One library powers chat, PDF export, RTF copy, HTML clipboard, and TTS pre-processing. Remove `MarkdownView` from AI Hub entirely.

- **`ChatMarkdownAttributedRenderer`** — both `AttributedString` and `NSAttributedString` outputs. Walks the same `ChatMarkdownDocument` and emits styled runs with paragraph styles, fonts, colors, link attributes. Replaces `MarkdownToRTFService.attributedString(from:)`.
- **`ChatMarkdownHTMLRenderer`** — emits an HTML string suitable for clipboard rich-text (table-friendly). Replaces `MarkdownToRTFService.html(from:)`. Optional embedded `<style>` block matching the current inline CSS in `MarkdownToRTFService.swift:73-80`.
- **`ChatMarkdownPlainTextRenderer`** — strips Markdown for TTS playback. Drops code blocks entirely (or replaces with a marker like "[code block]"), normalizes lists into spoken sentences, expands math to readable form. Replaces the regex-based stripping in `TextToSpeechService.swift`.
- Code blocks in `AttributedString`: monospaced font and background via run-level attributes; no inline views.
- Tables in `AttributedString`: tab-aligned text (PDF doesn't need full table layout, and RTF tables are pasteboard-fragile).
- AI Hub: replace `PDFMarkdownContentView` and `PDFCodeBlockStyle`/`PDFTableStyle` (`PDFMessageView.swift:74-167`) with `ChatMarkdownView` configured with the `.pdfLight` theme preset.
- AI Hub: replace `MarkdownToRTFService` with thin wrappers around `ChatMarkdownAttributedRenderer` and `ChatMarkdownHTMLRenderer`. Keep the public API of `MarkdownToRTFService` stable so call sites don't churn.
- AI Hub: replace the Markdown-stripping logic in `TextToSpeechService.swift` with `ChatMarkdownPlainTextRenderer`.
- Remove `MarkdownView` SPM dependency from `project.pbxproj`. Keep `swift-markdown` (still needed transitively via `ChatMarkdown`).
- Remove the `sanitize()` workaround in `MarkdownContentView.swift` — the crash was in `MarkdownView`'s `RangeAdjuster`, not relevant when we control the parser pipeline.
- Delete `MarkdownContentView.swift`, `PDFMarkdownContentView`, `PDFCodeBlockStyle`, `PDFTableStyle`, `CopyableCodeBlockStyle`, `CopyableCodeBlockView`; update all call sites to `ChatMarkdownView`.

**Done when:** `MarkdownView` no longer appears in `project.pbxproj`; PDF export, RTF copy, HTML clipboard, and TTS all use `ChatMarkdown`; AI Hub builds and passes existing tests (including `MarkdownSanitizationTests`) on macOS, iOS, visionOS.

---

### Phase 5 — Polish, Extraction, Stabilization

**Goal:** Library is production-quality, the path-dependency is replaced with a Git URL, and the codebase is in a state where a future `chatmarkdown-rust` could realistically match its behavior.

- Switch AI Hub from `.package(path: "../chatmarkdown-swift")` to `.package(url: "https://github.com/hra42/chatmarkdown-swift", branch: "main")`. Pin a specific commit in `Package.resolved`.
- Expand `Tests/Fixtures/` to ~30 real-world AI responses captured from AI Hub (various models, languages, edge cases). Each as `input.md` + `expected.json`.
- Add a "streaming fixture" format: a sequence of growing `input` snapshots and the expected stable-block-count after each. Validates the streaming semantics from `SPEC.md`.
- Expand `SPEC.md` with full streaming semantics, edge cases, fixture format documentation. This is the contract any future port must satisfy.
- README polish: usage example, theming example, custom code-block-style example. Still no version tags, still no support promise.
- Run on a real iOS device, real macOS, Vision Pro simulator. Verify performance, dark mode, dynamic type.
- Consider: `ChatMarkdownView` Preview Provider with all syntax features for documentation purposes.
- Consider: a small `chatmarkdown-cli` executable target that takes Markdown stdin and prints the AST as JSON — useful for debugging and as a reference for future ports.

**Done when:** AI Hub depends on the library by Git URL; the library has a documented spec, fixture-based test suite, and is in a state where stopping work for 6 months wouldn't leave anything broken or half-finished. No releases tagged — `main` is the contract, by design.

---

## Success Criteria

The project is successful if, after Phase 5:

1. AI Hub V2 has zero direct Markdown-rendering code — all of it lives in `ChatMarkdown`.
2. Streaming a long AI response feels visibly smoother than the current `MarkdownView`-based rendering.
3. PDF export, RTF copy, HTML clipboard, and TTS all share the same Markdown understanding (no parsing inconsistencies between paths).
4. The `RangeAdjuster` crash workaround is gone.
5. Every feature listed in **Current Feature Inventory** above renders correctly post-migration — verified by the existing `MarkdownSanitizationTests` plus the new fixture suite.
6. `SPEC.md` and `Tests/Fixtures/` are detailed enough that a `chatmarkdown-rust` port could be written and validated against the same behavioral contract.
