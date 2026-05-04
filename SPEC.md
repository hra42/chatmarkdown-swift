# chatmarkdown — Specification

This document defines the Markdown subset that `chatmarkdown` renderers (`-swift`, future `-rust`, `-ts`) must support, and the streaming semantics they must obey. The Swift implementation is the reference implementation; future ports validate against the same fixture suite under `Tests/Fixtures/`.

## Scope

`chatmarkdown` is a Markdown subset optimized for the output of large language models in conversational UIs. It is intentionally smaller than CommonMark or GFM. Anything not in the supported list below is dropped silently during normalization — unsupported source renders as plain text, never as a syntax error.

## Supported syntax

| Feature              | Syntax                           | Notes                                           |
| -------------------- | -------------------------------- | ----------------------------------------------- |
| ATX headings         | `# H1` … `###### H6`             | Levels 1–6 preserved; renderer may demote H5/H6 |
| Bold                 | `**text**`                       | Underscores also accepted                       |
| Italic               | `*text*`                         | Underscores also accepted                       |
| Inline code          | `` `code` ``                     |                                                 |
| Fenced code blocks   | ` ```lang\n…\n``` `              | Language label preserved (lowercased)           |
| Unordered lists      | `- ` / `* `                      | Nested via indentation                          |
| Ordered lists        | `1. `                            | Nested via indentation; start index preserved   |
| Blockquotes          | `> `                             | Nesting allowed                                 |
| Links                | `[text](url)`                    | Inline only                                     |
| Tables               | GFM pipe syntax                  | Column alignment preserved                      |
| Horizontal rule      | `---`                            |                                                 |
| Hard break           | `\\\n` or two trailing spaces    |                                                 |

## Unsupported / dropped

Documents containing any of the following render as plain text or are dropped silently. The full feature is never re-introduced — an LLM emitting these constructs is treated as an outlier, not a primary use case.

- Reference-style links and link definitions (`[ref]: url`)
- Setext headings (`===`, `---` underline-style)
- HTML inline and HTML blocks
- Footnotes
- Definition lists
- Images (`![alt](url)`) — dropped during Phase 1; rendering may revisit
- Custom block directives
- Math / LaTeX (inline `$…$` or block `$$…$$`)
- Strikethrough (`~~text~~`)

## Streaming semantics

A document is rendered as an ordered sequence of blocks. The contract below is what makes streaming cheap.

### Block identity

Each block in a document has a `BlockID` derived from two fields:

- `contentHash: UInt64` — the process-stable FNV-1a 64-bit hash of a canonical encoding of `(blockKind, payload)`. Same content → same hash across processes, machines, and language ports.
- `occurrenceIndex: Int` — the count of prior blocks in the same document that share the same `contentHash`. Disambiguates legitimate duplicates (e.g. two `---`, two empty paragraphs) which would otherwise collide as renderer view IDs.

The renderer uses a single `UInt64` `fingerprint = FNV-1a(contentHash || occurrenceIndex)` as the per-block identity passed to SwiftUI's `ForEach(id:)`. Future ports must compute the same fingerprint for the same input.

### Prefix stability invariant

For any two consecutive document snapshots S₁ and S₂ where S₂'s input is a strict suffix-extension of S₁'s, the BlockIDs `[0..<n)` of S₂ equal the first n BlockIDs of S₁ for some n ≥ |S₁.blocks| − 1. Equivalently: only the **trailing** block of S₁ may change identity between renders. Preceding blocks keep stable view identity, so the SwiftUI renderer skips re-layout for them.

### Unclosed code fence

If the input ends inside an open fenced code region (`` ``` `` or `~~~` opened with no matching close), the trailing `.codeBlock` carries `isClosed: false`. Once the closing fence arrives, the same code text re-emerges with `isClosed: true`. Because `isClosed` is part of the block's hashed payload, this produces a different `contentHash` — the trailing block re-renders. The invariant holds (only the trailing block changed).

The default renderer hides the copy button and shows a blinking caret while `isClosed: false`. The unclosed-fence detection is a line-level pre-pass over the raw markdown source; Apple's `swift-markdown` silently closes open fences, so the parser pipeline overrides `isClosed` on the trailing code block when the pre-pass reports an open fence.

### Unclosed inline emphasis

Per CommonMark, unmatched `*` / `**` / `_` / `__` delimiters are emitted as literal text. `chatmarkdown` does not deviate. As an LLM streams `**hello`, that paragraph contains the literal text `**hello`; once the closing `**` arrives, the paragraph re-parses to a paragraph containing a `.bold([.text("hello")])` span. The trailing block's `contentHash` changes, the invariant still holds.

### Performance target

The renderer must not re-evaluate `View.body` for blocks `0..<n−1` across consecutive snapshots that share a stable prefix of length n−1. Verified by `StreamingPrefixStabilityTests` (model-level, deterministic) and, in DEBUG builds, by `ChatMarkdownDebug.blockBodyEvaluations`.

## Test fixtures

`Tests/Fixtures/` contains paired files:

- `<name>.md` — input Markdown
- `<name>.expected.json` — JSON encoding of `[ChatMarkdownBlock]` (the normalized output)

The JSON shape is deliberately readable so future ports can decode and assert against the same files. Fixtures are the conformance suite; if a future port produces equivalent JSON for every fixture, it is conformant.

## Streaming fixtures

`Tests/Fixtures/streaming/<name>.json` files encode growing input snapshots with their expected per-step `BlockID`s and a derived `stableBlockCount` (the longest matching prefix of `blockIDs` against the previous step). Schema:

```json
{
  "description": "...",
  "steps": [
    {
      "input": "<markdown snapshot>",
      "stableBlockCount": <int>,
      "blockIDs": ["<16-char-lowercase-hex of fingerprint>", ...]
    }
  ]
}
```

`stableBlockCount` is derived (longest common prefix vs. previous step's `blockIDs`); the regenerator (`REGEN_FIXTURES=1 swift test --filter FixtureGenerator`) recomputes it. Hand-edit only the `input` strings.

Future ports validate by re-computing `BlockIDSequence` for each step's input and asserting equality with `blockIDs` plus prefix-stability vs. the previous step.
