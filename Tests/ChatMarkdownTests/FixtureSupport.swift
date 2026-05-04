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
