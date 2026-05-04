# Sorting in Swift

You can sort an array using `sorted()`. For example:

```swift
let nums = [3, 1, 4, 1, 5, 9, 2, 6]
let asc = nums.sorted()
```

Key points:

1. `sorted()` returns a new array.
2. Use `sorted(by:)` for a custom comparator.
3. For in-place sorting, use `sort()`.

> Tip: prefer `sorted()` for clarity in functional pipelines.

See the [official docs](https://developer.apple.com/documentation/swift/array) for more.

---

| Method      | Mutates | Returns        |
| ----------- | :-----: | -------------- |
| `sort()`    |   yes   | `Void`         |
| `sorted()`  |   no    | `[Element]`    |
