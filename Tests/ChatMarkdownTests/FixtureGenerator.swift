import Foundation
import XCTest
@testable import ChatMarkdown

// Run once to (re)generate .expected.json files in the source tree:
//
//   REGEN_FIXTURES=1 swift test --filter FixtureGenerator
//
// Skipped by default. Commit the generated JSON; later runs assert against it.
final class FixtureGeneratorTests: XCTestCase {
    func testRegenerate() throws {
        guard ProcessInfo.processInfo.environment["REGEN_FIXTURES"] == "1" else {
            throw XCTSkip("Set REGEN_FIXTURES=1 to regenerate fixtures.")
        }
        let dir = FixtureSupport.sourceFixturesDirectory()
        let encoder = FixtureSupport.encoder()
        for name in FixtureSupport.names {
            let input = try FixtureSupport.loadInput(name)
            let blocks = ChatMarkdownDocument(markdown: input).blocks
            let data = try encoder.encode(blocks)
            let url = dir.appendingPathComponent("\(name).expected.json")
            try data.write(to: url)
            print("wrote \(url.lastPathComponent) (\(blocks.count) blocks)")
        }

        // Streaming fixtures: replay each step, compute BlockIDs, fill in
        // stableBlockCount (longest matching prefix vs prior step) and
        // blockIDs (lowercase hex of fingerprints). Inputs are authoritative;
        // computed fields are overwritten.
        let streamDir = FixtureSupport.sourceStreamingFixturesDirectory()
        for name in FixtureSupport.streamingNames {
            let url = streamDir.appendingPathComponent("\(name).json")
            let data = try Data(contentsOf: url)
            var fixture = try JSONDecoder().decode(FixtureSupport.StreamingFixture.self, from: data)
            var prevIDs: [String] = []
            for i in fixture.steps.indices {
                let blocks = ChatMarkdownDocument(markdown: fixture.steps[i].input).blocks
                let ids = BlockIDSequence.make(blocks).map { String(format: "%016x", $0.fingerprint) }
                var stable = 0
                while stable < ids.count && stable < prevIDs.count && ids[stable] == prevIDs[stable] {
                    stable += 1
                }
                fixture.steps[i].blockIDs = ids
                fixture.steps[i].stableBlockCount = stable
                prevIDs = ids
            }
            let out = try encoder.encode(fixture)
            try out.write(to: url)
            print("wrote streaming/\(name).json (\(fixture.steps.count) steps)")
        }
    }
}
