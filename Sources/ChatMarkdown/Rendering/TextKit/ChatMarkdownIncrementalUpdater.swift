import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

enum ChatMarkdownIncrementalUpdater {
    /// Applies a build result to `storage` using the cheapest available
    /// mutation: either a single tail-only `replaceCharacters(in:with:)`
    /// covering the diverging suffix, or a full replace as a fallback.
    ///
    /// Returns the NSRange in the new storage that was rewritten (tail range
    /// for incremental updates; full new range for a full replace). Currently
    /// unused by the host but exposed for tests.
    @discardableResult
    static func apply(
        result: ChatMarkdownTextStorageBuildResult,
        to storage: NSTextStorage,
        previousBlockIDs: [BlockID],
        previousBlockRanges: [NSRange]
    ) -> NSRange {
        let oldStorageLength = storage.length

        // First-write or storage cleared elsewhere: full replace.
        if previousBlockIDs.isEmpty || previousBlockRanges.isEmpty {
            storage.beginEditing()
            storage.setAttributedString(result.attributed)
            storage.endEditing()
            return NSRange(location: 0, length: result.attributed.length)
        }

        // Sanity: if the cached side-index disagrees with storage, fall back.
        // (Storage may have been mutated externally — unlikely but defensive.)
        let oldCount = previousBlockIDs.count
        if previousBlockRanges.count != oldCount {
            return fullReplace(storage: storage, with: result.attributed)
        }

        // Longest common prefix by fingerprint.
        let newIDs = result.blockIDs
        var k = 0
        let limit = min(oldCount, newIDs.count)
        while k < limit, previousBlockIDs[k].fingerprint == newIDs[k].fingerprint {
            k += 1
        }

        if k == 0 {
            return fullReplace(storage: storage, with: result.attributed)
        }

        // Cut at the end of the last stable block (block k-1). The "\n\n"
        // separator that *was* (or will be) emitted between blocks k-1 and k
        // is part of the changed tail. This matters when:
        //   - the previous version had no block k (no separator existed),
        //     but the new version does (separator must be inserted).
        //   - the new version has no block k (separator must be removed).
        let lastStable = k - 1
        let oldChangeStart: Int = previousBlockRanges[lastStable].location
            + previousBlockRanges[lastStable].length
        let newChangeStart: Int = result.blockRanges[lastStable].location
            + result.blockRanges[lastStable].length

        // Defensive bounds check.
        guard oldChangeStart <= oldStorageLength,
              newChangeStart <= result.attributed.length else {
            return fullReplace(storage: storage, with: result.attributed)
        }

        let oldChangeRange = NSRange(
            location: oldChangeStart,
            length: oldStorageLength - oldChangeStart
        )
        let newTailLength = result.attributed.length - newChangeStart
        let tail: NSAttributedString
        if newTailLength == 0 {
            tail = NSAttributedString()
        } else {
            tail = result.attributed.attributedSubstring(
                from: NSRange(location: newChangeStart, length: newTailLength)
            )
        }

        // Skip the no-op case (rare: identical input passed twice).
        if oldChangeRange.length == 0 && tail.length == 0 {
            return NSRange(location: newChangeStart, length: 0)
        }

        storage.beginEditing()
        storage.replaceCharacters(in: oldChangeRange, with: tail)
        storage.endEditing()

        return NSRange(location: newChangeStart, length: tail.length)
    }

    @discardableResult
    private static func fullReplace(storage: NSTextStorage, with attributed: NSAttributedString) -> NSRange {
        storage.beginEditing()
        storage.setAttributedString(attributed)
        storage.endEditing()
        return NSRange(location: 0, length: attributed.length)
    }
}

#endif
