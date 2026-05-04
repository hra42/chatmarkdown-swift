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
    }
}
