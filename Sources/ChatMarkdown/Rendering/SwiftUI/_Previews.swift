#if DEBUG
import SwiftUI

private let kitchenSink = """
# Heading 1
## Heading 2
### Heading 3

A paragraph with **bold**, *italic*, `inline code`, and a [link](https://example.com).

- First bullet
- Second bullet with `code`
  - Nested bullet
1. Ordered one
2. Ordered two

> A blockquote
> with two lines.

```swift
func greet(_ name: String) -> String {
    // greet someone
    return "Hello, \\(name)!"
}
```

| Lang | Year |
| :--- | ---: |
| Swift | 2014 |
| Rust | 2010 |

---
"""

#Preview("Assistant") {
    ScrollView {
        ChatMarkdownView(kitchenSink, role: .assistant)
            .padding()
    }
}

#Preview("User") {
    ScrollView {
        ChatMarkdownView(kitchenSink, role: .user)
            .padding()
            .background(Color.blue)
    }
}

#Preview("PDF light") {
    ScrollView {
        ChatMarkdownView(kitchenSink, role: .assistant)
            .chatMarkdownTheme(.pdfLight)
            .padding()
            .background(Color.white)
    }
}
#endif
