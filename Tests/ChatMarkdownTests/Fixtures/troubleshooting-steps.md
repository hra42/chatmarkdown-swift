### Fixing "module not found" errors

1. Clean the build folder (Cmd+Shift+K) to clear stale module caches.
2. Reset Swift Package Manager state:

   ```bash
   rm -rf .build .swiftpm
   swift package reset
   ```

3. Resolve dependencies again:

   ```bash
   swift package resolve
   ```

4. Reopen the project in Xcode and rebuild.

If the error persists, check that the dependency is listed in **both** `Package.swift` and the target's `dependencies` array.
