import XCTest
@testable import ChatMarkdown

final class StreamingPrefixStabilityTests: XCTestCase {
    func test_streaming_fixtures_match_expected_block_ids_and_prefix_stability() throws {
        for name in FixtureSupport.streamingNames {
            let fixture = try FixtureSupport.loadStreaming(name)
            var prevIDs: [String] = []
            for (i, step) in fixture.steps.enumerated() {
                let blocks = ChatMarkdownDocument(markdown: step.input).blocks
                let ids = BlockIDSequence.make(blocks).map { String(format: "%016x", $0.fingerprint) }
                XCTAssertEqual(
                    ids, step.blockIDs,
                    "[\(name)#\(i)] computed BlockIDs differ from fixture"
                )
                let stable = step.stableBlockCount
                XCTAssertLessThanOrEqual(stable, ids.count)
                XCTAssertLessThanOrEqual(stable, prevIDs.count)
                if stable > 0 {
                    XCTAssertEqual(
                        Array(ids.prefix(stable)),
                        Array(prevIDs.prefix(stable)),
                        "[\(name)#\(i)] declared stable prefix not byte-equal to previous step"
                    )
                }
                // The stableBlockCount should be the longest matching prefix —
                // not arbitrarily lower. Verify maximality.
                let maxMatch = zip(ids, prevIDs).prefix { $0 == $1 }.count
                XCTAssertEqual(stable, maxMatch, "[\(name)#\(i)] stableBlockCount is not maximal")
                prevIDs = ids
            }
        }
    }

    func test_char_by_char_streaming_preserves_prior_block_identities() throws {
        // Programmatic test: type the mixed LLM response one character at a
        // time. For every transition where the block count does not shrink,
        // all-but-the-last block IDs must be unchanged. Equivalently: at most
        // the trailing block changes between consecutive prefixes.
        let source = try FixtureSupport.loadInput("mixed-llm-response")
        var prevIDs: [UInt64] = []
        var prevCount = 0
        var i = source.startIndex
        while i < source.endIndex {
            let prefix = String(source[..<source.index(after: i)])
            let blocks = ChatMarkdownDocument(markdown: prefix).blocks
            let ids = BlockIDSequence.make(blocks).map { $0.fingerprint }
            if ids.count >= prevCount && prevCount >= 1 {
                // Prefix [0 ..< prevCount-1] must be unchanged when the block
                // count stayed equal or grew.
                let n = prevCount - 1
                if n > 0 {
                    XCTAssertEqual(
                        Array(ids.prefix(n)),
                        Array(prevIDs.prefix(n)),
                        "prior-prefix block IDs changed at offset \(source.distance(from: source.startIndex, to: i))"
                    )
                }
            }
            prevIDs = ids
            prevCount = ids.count
            i = source.index(after: i)
        }
    }
}
