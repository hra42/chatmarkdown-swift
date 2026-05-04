import XCTest
@testable import ChatMarkdown

final class AttributedRendererTests: XCTestCase {
    func testAllFixturesProduceNonNilOutput() throws {
        for name in FixtureSupport.names {
            let md = try FixtureSupport.loadInput(name)
            let attr = ChatMarkdownAttributedRenderer.render(md)
            let ns = ChatMarkdownAttributedRenderer.renderNS(md)

            // Empty doc → empty output. Otherwise text length should be > 0.
            if md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                XCTAssertEqual(String(attr.characters).count, 0, "empty input produced non-empty output for \(name)")
                XCTAssertEqual(ns.length, 0, "empty NS output expected for \(name)")
            } else {
                XCTAssertGreaterThan(String(attr.characters).count, 0, "no output for \(name)")
                XCTAssertGreaterThan(ns.length, 0, "no NS output for \(name)")
            }
        }
    }

    func testEmptyInputIsSafe() {
        let attr = ChatMarkdownAttributedRenderer.render("")
        let ns = ChatMarkdownAttributedRenderer.renderNS("")
        XCTAssertEqual(String(attr.characters), "")
        XCTAssertEqual(ns.string, "")
    }

    func testCodeBlockCarriesMonospaceFontInNS() throws {
        let md = try FixtureSupport.loadInput("code-fence-swift")
        let ns = ChatMarkdownAttributedRenderer.renderNS(md)
        let body = ns.string
        XCTAssertTrue(body.contains("greet"), "code body missing in NS output")

        // Find the location of "greet" and check the run carries the monospace font.
        let nsBody = body as NSString
        let range = nsBody.range(of: "greet")
        XCTAssertNotEqual(range.location, NSNotFound)
        let attrs = ns.attributes(at: range.location, effectiveRange: nil)
        let font = attrs[.font] as? PlatformFont
        XCTAssertNotNil(font, "code run missing .font attribute")
        // monospaced fonts on Apple platforms expose isFixedPitch on NSFont
        // and a fixed-pitch trait on UIFont — quick sanity check.
        #if canImport(AppKit)
        XCTAssertTrue(font?.isFixedPitch ?? false, "code font should be monospaced")
        #else
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) ?? false,
                      "code font should be monospaced")
        #endif
    }

    func testParagraphTextRoundTripsThroughAttributedString() {
        let md = "Hello **bold** and *italic* and `code`."
        let attr = ChatMarkdownAttributedRenderer.render(md)
        let plain = String(attr.characters)
        XCTAssertTrue(plain.contains("Hello"))
        XCTAssertTrue(plain.contains("bold"))
        XCTAssertTrue(plain.contains("italic"))
        XCTAssertTrue(plain.contains("code"))
    }

    func testLinkAttributeIsSetInNS() {
        let md = "Visit [Apple](https://apple.com) today."
        let ns = ChatMarkdownAttributedRenderer.renderNS(md)
        let body = ns.string as NSString
        let r = body.range(of: "Apple")
        XCTAssertNotEqual(r.location, NSNotFound)
        let attrs = ns.attributes(at: r.location, effectiveRange: nil)
        XCTAssertNotNil(attrs[.link], "link attribute missing")
    }
}
