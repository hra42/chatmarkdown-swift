import Foundation
import XCTest
@testable import ChatMarkdown

enum FixtureSupport {
    static let names: [String] = [
        "simple-paragraph",
        "headings",
        "code-fence-swift",
        "nested-list",
        "gfm-table",
        "blockquote",
        "mixed-llm-response",
        "tabs-and-crlf",
        "unclosed-fence",
        "empty",
    ]

    static func loadInput(_ name: String) throws -> String {
        let url = try requireURL(name: name, ext: "md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func loadExpected(_ name: String) throws -> [ChatMarkdownBlock] {
        let url = try requireURL(name: name, ext: "expected.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ChatMarkdownBlock].self, from: data)
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static let streamingNames: [String] = [
        "typing-paragraph-then-code",
        "duplicate-blocks",
    ]

    struct StreamingFixture: Codable {
        var description: String
        var steps: [Step]

        struct Step: Codable {
            var input: String
            var stableBlockCount: Int
            var blockIDs: [String]
        }
    }

    static func loadStreaming(_ name: String) throws -> StreamingFixture {
        let url = try requireStreamingURL(name: name)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StreamingFixture.self, from: data)
    }

    static func sourceStreamingFixturesDirectory() -> URL {
        sourceFixturesDirectory().appendingPathComponent("streaming")
    }

    private static func requireStreamingURL(name: String) throws -> URL {
        if let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/streaming") {
            return url
        }
        let direct = sourceStreamingFixturesDirectory().appendingPathComponent("\(name).json")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        throw NSError(
            domain: "FixtureSupport",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing streaming fixture: \(name).json"]
        )
    }

    static func sourceFixturesDirectory() -> URL {
        // #filePath points at this file inside Tests/ChatMarkdownTests/.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    private static func requireURL(name: String, ext: String) throws -> URL {
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        // Fall back to source tree (helpful when bundle resource lookup misses
        // a multi-extension file like *.expected.json under some toolchain
        // configurations).
        let direct = sourceFixturesDirectory().appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        throw NSError(
            domain: "FixtureSupport",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(name).\(ext)"]
        )
    }
}
