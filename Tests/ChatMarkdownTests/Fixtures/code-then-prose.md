```swift
let theme = ChatMarkdownTheme.assistant
ChatMarkdownView(markdown).chatMarkdownTheme(theme)
```

The `.assistant` preset uses the system body font and the accent color for links. For user-bubble messages, swap to `.user`, which inverts the foreground for higher contrast on a coloured background.
