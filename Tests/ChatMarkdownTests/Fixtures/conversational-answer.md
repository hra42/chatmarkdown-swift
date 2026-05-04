## What's the difference between `let` and `var`?

`let` declares a *constant* — once assigned, the binding cannot point at a different value.

`var` declares a *variable* — the binding can be reassigned.

```swift
let pi = 3.14159
var counter = 0
counter += 1
```

Use `let` by default; only reach for `var` when you actually need mutation. Xcode will warn you if you declare a `var` that is never reassigned, suggesting you change it to `let`.
