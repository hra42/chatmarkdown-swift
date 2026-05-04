#if canImport(AppKit) || canImport(UIKit)

import Foundation
import XCTest
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Pins the TextKit renderer's storage contract for representative inputs.
/// Each fixture is a paired `<name>.md` + `<name>.textkit.json` under
/// `Tests/ChatMarkdownTests/Fixtures/textkit/`. The JSON records:
///
///   - `length`: total NSAttributedString length the builder produces
///   - `attachmentSlots`: every run carrying `.chatMarkdownAttachmentSlot`,
///                        as `{location, length, kind}`
///   - `blockKinds`: in-order kinds of the document's blocks
///
/// To regenerate after deliberate builder changes:
///
///   REGEN_FIXTURES=1 swift test --filter TextKitFixturesConformanceTests
final class TextKitFixturesConformanceTests: XCTestCase {

    static let names: [String] = [
        "prose-only",
        "code-fence-swift",
        "table-aligned",
        "mixed",
        "blockquote-and-hr",
    ]

    func testEachFixtureMatchesExpectedContract() throws {
        if ProcessInfo.processInfo.environment["REGEN_FIXTURES"] == "1" {
            try regenerateAll()
            return
        }
        for name in Self.names {
            let observed = try buildExpected(for: name)
            let expected = try loadExpected(name)
            XCTAssertEqual(
                observed, expected,
                "TextKit conformance mismatch for fixture \(name).\n" +
                "Re-run with REGEN_FIXTURES=1 if the change is intentional."
            )
        }
    }

    // MARK: - Build / load

    private func buildExpected(for name: String) throws -> ExpectedContract {
        let markdown = try loadMarkdown(name)
        let document = ChatMarkdownDocument(markdown: markdown)
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(
            document: document,
            theme: ChatMarkdownTheme()
        )
        let attributed = result.attributed

        var slots: [ExpectedContract.Slot] = []
        attributed.enumerateAttribute(
            .chatMarkdownAttachmentSlot,
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { value, range, _ in
            guard let box = value as? ChatMarkdownAttachmentSlotBox else { return }
            slots.append(.init(
                location: range.location,
                length: range.length,
                kind: box.payload.kind.rawValue
            ))
        }

        let blockKinds = document.blocks.map { $0.kind.rawValue }

        return ExpectedContract(
            length: attributed.length,
            attachmentSlots: slots,
            blockKinds: blockKinds
        )
    }

    private func loadMarkdown(_ name: String) throws -> String {
        let url = try resolveFixtureURL(name: name, ext: "md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func loadExpected(_ name: String) throws -> ExpectedContract {
        let url = try resolveFixtureURL(name: name, ext: "textkit.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ExpectedContract.self, from: data)
    }

    private func regenerateAll() throws {
        let dir = Self.sourceTextKitFixturesDirectory()
        let encoder = FixtureSupport.encoder()
        for name in Self.names {
            let observed = try buildExpected(for: name)
            let data = try encoder.encode(observed)
            let url = dir.appendingPathComponent("\(name).textkit.json")
            try data.write(to: url)
            print("wrote textkit/\(name).textkit.json (length=\(observed.length), slots=\(observed.attachmentSlots.count))")
        }
    }

    // MARK: - Fixture URL resolution

    private func resolveFixtureURL(name: String, ext: String) throws -> URL {
        if let url = Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Fixtures/textkit"
        ) {
            return url
        }
        let direct = Self.sourceTextKitFixturesDirectory()
            .appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        throw NSError(
            domain: "TextKitFixturesConformanceTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing TextKit fixture: \(name).\(ext)"]
        )
    }

    static func sourceTextKitFixturesDirectory() -> URL {
        FixtureSupport.sourceFixturesDirectory().appendingPathComponent("textkit")
    }

    // MARK: - Contract model

    struct ExpectedContract: Codable, Equatable {
        var length: Int
        var attachmentSlots: [Slot]
        var blockKinds: [String]

        struct Slot: Codable, Equatable {
            var location: Int
            var length: Int
            var kind: String
        }
    }
}

#endif
