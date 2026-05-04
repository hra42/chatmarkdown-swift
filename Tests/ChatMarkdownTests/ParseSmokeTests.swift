import XCTest
@testable import ChatMarkdown

final class ParseSmokeTests: XCTestCase {
    func testEveryFixtureParsesAndMatchesSnapshot() throws {
        for name in FixtureSupport.names {
            let input = try FixtureSupport.loadInput(name)
            let parsed = ChatMarkdownDocument(markdown: input).blocks
            let expected = try FixtureSupport.loadExpected(name)
            XCTAssertEqual(parsed, expected, "fixture \(name) drifted from snapshot")
        }
    }
}
