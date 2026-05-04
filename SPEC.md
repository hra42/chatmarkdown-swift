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

A document is rendered as an ordered sequence of blocks. During streaming:

- Only the **trailing block** can change between renders. All preceding blocks are stable and reused by the renderer via content-hash identity.
- An **unclosed code fence** at end-of-stream is preserved as a code block (Phase 1: parser tolerates it; Phase 3 will surface `isClosed: false` to the renderer for cursor styling).
- An **unclosed bold/italic span** at end-of-stream renders as plain text up to the cursor; closing it triggers re-style of the trailing block only.

Block fingerprinting uses a process-stable FNV-1a 64-bit hash over a canonical encoding of `(blockKind, payload)`. Same content → same hash across processes and machines, so a future `chatmarkdown-rust` can match the Swift behavior bit-for-bit.

## Test fixtures

`Tests/Fixtures/` contains paired files:

- `<name>.md` — input Markdown
- `<name>.expected.json` — JSON encoding of `[ChatMarkdownBlock]` (the normalized output)

The JSON shape is deliberately readable so future ports can decode and assert against the same files. Fixtures are the conformance suite; if a future port produces equivalent JSON for every fixture, it is conformant.

## Streaming fixtures

Reserved for Phase 3. Will encode a sequence of growing input snapshots paired with expected stable-block-count after each.
