Common Swift concurrency primitives:

- **`Task`** — schedules an asynchronous unit of work.
- **`async let`** — runs child tasks in parallel and awaits them later.
- **`actor`** — protects mutable state from data races by serialising access.
- **`@MainActor`** — pins work to the main thread, useful for UI updates.
