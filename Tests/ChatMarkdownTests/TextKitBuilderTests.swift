#if canImport(AppKit) || canImport(UIKit)

import XCTest
@testable import ChatMarkdown

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class TextKitBuilderTests: XCTestCase {

    // MARK: - All fixtures

    func testEveryFixtureProducesAttributedStringWithBlockKinds() throws {
        for name in FixtureSupport.names where name != "empty" {
            let markdown = try FixtureSupport.loadInput(name)
            let document = ChatMarkdownDocument(markdown: markdown)
            let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

            XCTAssertGreaterThan(attributed.length, 0, "Empty output for fixture: \(name)")

            let coverage = blockKindCoverage(in: attributed)
            // Every non-whitespace character should carry a block kind.
            XCTAssertEqual(
                coverage.uncoveredNonWhitespace, 0,
                "Fixture \(name) has \(coverage.uncoveredNonWhitespace) non-whitespace characters without a block kind"
            )
        }
    }

    func testEmptyDocumentProducesEmptyString() {
        let document = ChatMarkdownDocument(markdown: "")
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())
        XCTAssertEqual(attributed.length, 0)
    }

    // MARK: - Code block

    func testCodeFenceSwiftEmitsExactlyOneAttachmentSlot() throws {
        let markdown = try FixtureSupport.loadInput("code-fence-swift")
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        let slots = collectAttachmentSlots(in: attributed)
        XCTAssertEqual(slots.count, 1)
        guard case .codeBlock(let language, let code, _) = slots[0].payload else {
            return XCTFail("Expected code block payload, got \(slots[0].payload)")
        }
        XCTAssertEqual(language, "swift")
        XCTAssertTrue(code.contains("greet"), "Code body missing identifier from fixture")

        // Body code text must remain in the storage as actual selectable text.
        XCTAssertTrue(attributed.string.contains("greet"))
        XCTAssertTrue(attributed.string.contains("\u{FFFC}"))

        // Body must use a monospaced font.
        XCTAssertTrue(hasMonospacedRun(in: attributed))
    }

    // MARK: - Table

    func testGFMTableEmitsExactlyOneAttachmentSlotWithPayload() throws {
        let markdown = try FixtureSupport.loadInput("gfm-table")
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        let slots = collectAttachmentSlots(in: attributed)
        XCTAssertEqual(slots.count, 1)
        guard case .table(let headers, let rows, let alignments) = slots[0].payload else {
            return XCTFail("Expected table payload, got \(slots[0].payload)")
        }
        XCTAssertEqual(headers.count, 3)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(alignments.count, 3)

        // Single FFFC character. Vertical space is reserved by the
        // ChatMarkdownTableAttachment's attachmentBounds(...) — see the
        // overlay tests for the layout-time assertion.
        XCTAssertEqual(slots[0].range.length, 1,
                       "Table slot must be a single FFFC character; height comes from NSTextAttachment")

        let attachment = attributed.attribute(.attachment, at: slots[0].range.location, effectiveRange: nil)
        XCTAssertTrue(attachment is ChatMarkdownTableAttachment,
                       "Table slot must carry a ChatMarkdownTableAttachment")
        if let table = attachment as? ChatMarkdownTableAttachment {
            XCTAssertEqual(table.payload, slots[0].payload)
        }
    }

    // MARK: - Blockquote

    func testBlockquoteFixtureMarksRuleAttribute() throws {
        let markdown = try FixtureSupport.loadInput("blockquote")
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        var sawRule = false
        attributed.enumerateAttribute(
            .chatMarkdownBlockquoteRule,
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { value, _, _ in
            if (value as? Bool) == true { sawRule = true }
        }
        XCTAssertTrue(sawRule, "Blockquote fixture produced no chatMarkdownBlockquoteRule runs")
    }

    func testMultiParagraphBlockquoteRuleIsContiguous() {
        let markdown = "> p1\n>\n> p2"
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        var ruleRanges: [NSRange] = []
        attributed.enumerateAttribute(
            .chatMarkdownBlockquoteRule,
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { value, range, _ in
            if (value as? Bool) == true { ruleRanges.append(range) }
        }

        XCTAssertEqual(
            ruleRanges.count, 1,
            "Multi-paragraph blockquote must produce a single contiguous rule run, got \(ruleRanges.count): \(ruleRanges)"
        )
        guard let only = ruleRanges.first else { return }
        let nsString = attributed.string as NSString
        let covered = nsString.substring(with: only)
        XCTAssertTrue(covered.contains("p1"))
        XCTAssertTrue(covered.contains("p2"))
        XCTAssertTrue(covered.contains("\n"), "Inter-paragraph separator must carry the rule attribute")
    }

    // MARK: - Horizontal rule

    func testHorizontalRuleFixtureMarksRuleAttribute() throws {
        let markdown = try FixtureSupport.loadInput("horizontal-rule-separating")
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        var sawRule = false
        attributed.enumerateAttribute(
            .chatMarkdownHorizontalRule,
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { value, _, _ in
            if (value as? Bool) == true { sawRule = true }
        }
        XCTAssertTrue(sawRule, "Horizontal rule fixture produced no chatMarkdownHorizontalRule runs")
    }

    // MARK: - Lists

    func testNestedListEmitsListMarkersWithIncreasingIndent() throws {
        let markdown = try FixtureSupport.loadInput("nested-list")
        let document = ChatMarkdownDocument(markdown: markdown)
        let attributed = ChatMarkdownTextStorageBuilder.build(document: document, theme: ChatMarkdownTheme())

        var markerHeadIndents: [CGFloat] = []
        attributed.enumerateAttribute(
            .chatMarkdownListMarker,
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { value, range, _ in
            guard (value as? Bool) == true else { return }
            if let style = attributed.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle {
                markerHeadIndents.append(style.headIndent)
            }
        }
        XCTAssertFalse(markerHeadIndents.isEmpty, "No list markers produced for nested-list fixture")
        XCTAssertGreaterThan(markerHeadIndents.max() ?? 0, markerHeadIndents.min() ?? 0, "Expected at least one nested marker with greater head indent")
    }

    // MARK: - Determinism / diffability

    func testDeterministicBuildForSameDocument() throws {
        let markdown = try FixtureSupport.loadInput("mixed-llm-response")
        let document = ChatMarkdownDocument(markdown: markdown)
        let theme = ChatMarkdownTheme()
        let a = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)
        let b = ChatMarkdownTextStorageBuilder.build(document: document, theme: theme)
        XCTAssertEqual(a.length, b.length)
        XCTAssertEqual(a.string, b.string)
    }

    // MARK: - buildWithIndex (Phase 4)

    func testBuildWithIndexBlockRangesCoverEachBlock() {
        let document = ChatMarkdownDocument(markdown: "# Heading\n\nAlpha paragraph.\n\nBeta paragraph.")
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: ChatMarkdownTheme())

        XCTAssertEqual(result.blockRanges.count, 3)
        XCTAssertEqual(result.blockIDs.count, 3)
        XCTAssertGreaterThan(result.attributed.length, 0)

        // Ranges should be in-order, non-overlapping, within bounds, and each
        // should carry .chatMarkdownBlockID matching the corresponding ID at
        // its starting character.
        var prevEnd = -1
        for (i, range) in result.blockRanges.enumerated() {
            XCTAssertGreaterThanOrEqual(range.location, prevEnd, "range \(i) overlaps predecessor")
            XCTAssertLessThanOrEqual(range.location + range.length, result.attributed.length)
            XCTAssertGreaterThan(range.length, 0, "range \(i) is empty")
            prevEnd = range.location + range.length

            let attr = result.attributed.attribute(.chatMarkdownBlockID, at: range.location, effectiveRange: nil)
            guard let number = attr as? NSNumber else {
                return XCTFail("missing chatMarkdownBlockID at start of range \(i)")
            }
            XCTAssertEqual(number.uint64Value, result.blockIDs[i].fingerprint)
        }
    }

    func testBuildWithIndexEmptyDocument() {
        let document = ChatMarkdownDocument(markdown: "")
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: ChatMarkdownTheme())
        XCTAssertEqual(result.attributed.length, 0)
        XCTAssertTrue(result.blockRanges.isEmpty)
        XCTAssertTrue(result.blockIDs.isEmpty)
    }

    func testBuildWithIndexIDsMatchBlockIDSequence() throws {
        let markdown = try FixtureSupport.loadInput("mixed-llm-response")
        let document = ChatMarkdownDocument(markdown: markdown)
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: ChatMarkdownTheme())
        let expected = BlockIDSequence.make(document.blocks)
        XCTAssertEqual(result.blockIDs.map(\.fingerprint), expected.map(\.fingerprint))
    }

    // MARK: - Helpers

    private struct AttachmentSlotHit {
        let range: NSRange
        let payload: ChatMarkdownAttachmentSlotPayload
    }

    private func collectAttachmentSlots(in s: NSAttributedString) -> [AttachmentSlotHit] {
        var hits: [AttachmentSlotHit] = []
        s.enumerateAttribute(
            .chatMarkdownAttachmentSlot,
            in: NSRange(location: 0, length: s.length),
            options: []
        ) { value, range, _ in
            guard let box = value as? ChatMarkdownAttachmentSlotBox else { return }
            hits.append(AttachmentSlotHit(range: range, payload: box.payload))
        }
        return hits
    }

    private func hasMonospacedRun(in s: NSAttributedString) -> Bool {
        var found = false
        s.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: s.length),
            options: []
        ) { value, _, stop in
            guard let font = value as? PlatformFont else { return }
            #if canImport(AppKit)
            if font.fontName.lowercased().contains("menlo") || font.fontName.lowercased().contains("mono") {
                found = true
                stop.pointee = true
            }
            #else
            if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) ||
                font.fontName.lowercased().contains("mono") {
                found = true
                stop.pointee = true
            }
            #endif
        }
        return found
    }

    private struct CoverageReport {
        var uncoveredNonWhitespace: Int
    }

    private func blockKindCoverage(in s: NSAttributedString) -> CoverageReport {
        var uncovered = 0
        let str = s.string as NSString
        var i = 0
        while i < s.length {
            let kind = s.attribute(.chatMarkdownBlockKind, at: i, effectiveRange: nil)
            if kind == nil {
                let scalar = str.substring(with: NSRange(location: i, length: 1))
                if !scalar.allSatisfy({ $0.isWhitespace || $0.isNewline }) {
                    uncovered += 1
                }
            }
            i += 1
        }
        return CoverageReport(uncoveredNonWhitespace: uncovered)
    }
}

#endif
