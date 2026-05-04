#if canImport(AppKit) || canImport(UIKit)

import XCTest
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class TextKitStreamingTests: XCTestCase {

    // MARK: - Direct updater behavior (per fixture)

    func testStreamingFixturesIncrementalUpdates() throws {
        for name in FixtureSupport.streamingNames {
            let fixture = try FixtureSupport.loadStreaming(name)
            let theme = ChatMarkdownTheme()

            let storage = NSTextStorage()
            var prevIDs: [BlockID] = []
            var prevRanges: [NSRange] = []

            for (i, step) in fixture.steps.enumerated() {
                let document = ChatMarkdownDocument(markdown: step.input)
                let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: theme)

                let counter = StorageEditCounter(storage: storage)
                let returnedRange = ChatMarkdownIncrementalUpdater.apply(
                    result: result,
                    to: storage,
                    previousBlockIDs: prevIDs,
                    previousBlockRanges: prevRanges
                )
                counter.invalidate()

                // Each call must produce at most one processEditing cycle
                // (begin/end editing brackets coalesce mutations).
                XCTAssertLessThanOrEqual(
                    counter.editingCycles, 1,
                    "[\(name)#\(i)] expected ≤1 processEditing cycle, saw \(counter.editingCycles)"
                )

                // After applying, storage matches a fresh full build by
                // string content. (Attribute equality is stricter than we
                // need — replaceCharacters may extend run attributes from
                // surrounding chars in ways that don't affect display, but
                // do affect NSAttributedString.isEqual. Visual correctness
                // is verified by the host integration test.)
                XCTAssertEqual(
                    storage.string, result.attributed.string,
                    "[\(name)#\(i)] storage string diverged from full-build expected output"
                )

                // Block IDs must be stamped at the start of each block range.
                for (bi, range) in result.blockRanges.enumerated() {
                    let attr = storage.attribute(.chatMarkdownBlockID, at: range.location, effectiveRange: nil)
                    guard let number = attr as? NSNumber else {
                        XCTFail("[\(name)#\(i)] block \(bi) missing chatMarkdownBlockID at \(range.location)")
                        continue
                    }
                    XCTAssertEqual(
                        number.uint64Value, result.blockIDs[bi].fingerprint,
                        "[\(name)#\(i)] block \(bi) blockID mismatch"
                    )
                }

                // Block IDs match BlockIDSequence for the input blocks.
                let expectedIDs = BlockIDSequence.make(document.blocks)
                XCTAssertEqual(
                    result.blockIDs.map(\.fingerprint),
                    expectedIDs.map(\.fingerprint),
                    "[\(name)#\(i)] result.blockIDs disagree with BlockIDSequence"
                )

                // For steps with a non-empty stable prefix, the rewritten
                // range must start at or after the END of the last stable
                // block in the new storage. Block content before that point
                // is preserved bit-for-bit.
                let stable = step.stableBlockCount
                if stable > 0, !prevRanges.isEmpty {
                    let lastStable = stable - 1
                    let boundary = result.blockRanges[lastStable].location
                        + result.blockRanges[lastStable].length
                    XCTAssertGreaterThanOrEqual(
                        returnedRange.location, boundary,
                        "[\(name)#\(i)] mutation touched stable prefix (loc \(returnedRange.location) < boundary \(boundary))"
                    )
                }

                prevIDs = result.blockIDs
                prevRanges = result.blockRanges
            }
        }
    }

    // MARK: - End-to-end host apply

    func testHostApplyKeepsStorageStateConsistent() throws {
        let fixture = try FixtureSupport.loadStreaming("typing-paragraph-then-code")
        let theme = ChatMarkdownTheme()
        let view = makeTextView()

        for (i, step) in fixture.steps.enumerated() {
            let document = ChatMarkdownDocument(markdown: step.input)
            ChatMarkdownTextKitHost.apply(document: document, theme: theme, to: view)

            let storage = textStorage(of: view)
            let expected = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)
            XCTAssertEqual(storage.length, expected.length, "[\(i)] length mismatch")
            XCTAssertEqual(storage.string, expected.string, "[\(i)] string mismatch")

            let cachedIDs = blockIDs(of: view).map(\.fingerprint)
            XCTAssertEqual(
                cachedIDs,
                BlockIDSequence.make(document.blocks).map(\.fingerprint),
                "[\(i)] cached blockIDs out of sync"
            )
        }
    }

    // MARK: - Helpers

    private func makeTextView() -> ChatMarkdownPlatformTextView {
        #if canImport(AppKit)
        let view = ChatMarkdownNSTextView(frame: .zero)
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        return view
        #else
        let view = ChatMarkdownUITextView(frame: .zero, textContainer: nil)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
        #endif
    }

    private func textStorage(of view: ChatMarkdownPlatformTextView) -> NSTextStorage {
        #if canImport(AppKit)
        return view.textStorage!
        #else
        return view.textStorage
        #endif
    }

    private func blockIDs(of view: ChatMarkdownPlatformTextView) -> [BlockID] {
        view.chatMarkdownBlockIDs
    }
}

#if canImport(AppKit)
private typealias ChatMarkdownPlatformTextView = ChatMarkdownNSTextView
#else
private typealias ChatMarkdownPlatformTextView = ChatMarkdownUITextView
#endif

/// Counts the number of `processEditing` cycles fired by an `NSTextStorage`
/// between construction and `invalidate()`. Because Phase 4 wraps every
/// mutation in `beginEditing()/endEditing()`, one logical update == one cycle.
private final class StorageEditCounter: NSObject {
    private weak var storage: NSTextStorage?
    private var observer: NSObjectProtocol?
    private(set) var editingCycles: Int = 0

    init(storage: NSTextStorage) {
        self.storage = storage
        super.init()
        self.observer = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: storage,
            queue: nil
        ) { [weak self] _ in
            self?.editingCycles += 1
        }
    }

    func invalidate() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    deinit {
        invalidate()
    }
}

#endif
