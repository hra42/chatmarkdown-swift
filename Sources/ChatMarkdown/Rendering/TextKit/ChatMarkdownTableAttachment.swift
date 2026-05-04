import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

/// Custom `NSTextAttachment` for table slots. The layout manager queries the
/// attachment for its size during glyph layout; we measure the SwiftUI table
/// at the available container width and report it so TextKit reserves an
/// accurate vertical rect. The overlay manager then paints the SwiftUI table
/// over that exact rect — no overlap with following text.
///
/// Per-platform sizing path:
/// - **AppKit**: `NSLayoutManager` queries `NSTextAttachmentCellProtocol` —
///   `attachmentBounds(for:...)` is *never* called in macOS. We install a
///   `ChatMarkdownTableAttachmentCell` whose `cellFrame(for:...)` calls back
///   into the attachment.
/// - **UIKit**: TextKit 1 (forced via `usingTextLayoutManager: false`) calls
///   `attachmentBounds(for:...)` directly.
///
/// The attachment paints nothing on its own; all visible chrome comes from
/// the SwiftUI overlay.
final class ChatMarkdownTableAttachment: NSTextAttachment, @unchecked Sendable {

    let payload: ChatMarkdownAttachmentSlotPayload

    /// Theme & style are injected by the host after each `apply()` so the
    /// measurement uses the same SwiftUI tree the overlay paints. Mutated
    /// only on the main thread (host's `apply()`).
    var theme: ChatMarkdownTheme
    var tableStyle: AnyChatMarkdownTableStyle

    /// Per-instance cache keyed by integer-rounded width. Cleared by the
    /// host's layout hooks when container width changes. Mutated only from
    /// the main thread (TextKit calls into the attachment on the main thread
    /// during layout).
    private var heightCache: [Int: CGFloat] = [:]

    init(
        payload: ChatMarkdownAttachmentSlotPayload,
        theme: ChatMarkdownTheme,
        tableStyle: AnyChatMarkdownTableStyle
    ) {
        self.payload = payload
        self.theme = theme
        self.tableStyle = tableStyle
        super.init(data: nil, ofType: nil)
        #if canImport(AppKit)
        // Install a sizing cell — required on macOS, where NSLayoutManager
        // routes attachment sizing through NSTextAttachmentCellProtocol and
        // ignores the `attachmentBounds(...)` override entirely.
        self.attachmentCell = ChatMarkdownTableAttachmentCell(attachment: self)
        #endif
    }

    required init?(coder: NSCoder) {
        // Not used — these attachments are constructed in-process by the
        // builder, never archived. Provide a stub so the override compiles.
        fatalError("ChatMarkdownTableAttachment is not decodable")
    }

    func invalidateHeightCache() {
        heightCache.removeAll(keepingCapacity: true)
    }

    // MARK: - Sizing entry point (called from cell on AppKit, override on UIKit)

    /// Compute the attachment rect for a given container width and proposed
    /// line fragment. Caches by integer-rounded width.
    func computeBounds(containerWidth: CGFloat, lineFrag: CGRect) -> CGRect {
        let measureWidth = resolveMeasurementWidth(
            containerWidth: containerWidth,
            lineFrag: lineFrag
        )
        let lineWidth = lineFrag.width.isFinite && lineFrag.width > 0
            ? lineFrag.width
            : measureWidth

        // No usable width yet (view hasn't been sized) — reserve one
        // body-line of height as a placeholder. The host's width-change
        // hook will invalidate layout once the container has real bounds.
        guard measureWidth.isFinite, measureWidth > 0 else {
            let font = TextKitThemeAdapter.bodyFont(for: theme)
            let fallback = font.ascender - font.descender + font.leading
            return CGRect(x: 0, y: 0, width: max(0, lineWidth), height: ceil(fallback))
        }

        let key = Int(measureWidth.rounded())
        let height: CGFloat
        if let cached = heightCache[key] {
            height = cached
        } else {
            height = measureHeight(at: measureWidth)
            heightCache[key] = height
        }

        return CGRect(x: 0, y: 0, width: lineWidth, height: ceil(height))
    }

    #if canImport(UIKit)
    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        let containerWidth: CGFloat = textContainer?.size.width ?? .nan
        return computeBounds(containerWidth: containerWidth, lineFrag: lineFrag)
    }
    #endif

    // MARK: - Measurement

    private func resolveMeasurementWidth(
        containerWidth: CGFloat,
        lineFrag: CGRect
    ) -> CGFloat {
        if containerWidth.isFinite, containerWidth > 0 {
            return containerWidth
        }
        return lineFrag.width
    }

    private func measureHeight(at width: CGFloat) -> CGFloat {
        // SwiftUI hosting must run on the main thread. TextKit guarantees
        // `attachmentBounds` is called there during glyph layout, but Swift 6
        // wants an explicit isolation hop. Capture only value types in the
        // closure so it remains Sendable.
        let payload = self.payload
        let theme = self.theme
        let tableStyle = self.tableStyle
        return MainActor.assumeIsolated {
            let root = ChatMarkdownOverlayRoot.makeView(
                payload: payload,
                codeBlockStyle: AnyChatMarkdownCodeBlockStyle(DefaultChatMarkdownCodeBlockStyle()),
                tableStyle: tableStyle,
                theme: theme
            )

            #if canImport(AppKit)
            // Pin the hosting view's width via Auto Layout so `fittingSize`
            // returns a height that respects horizontal-ScrollView and other
            // shrink-fit subviews. Frame-only sizing reports ~0pt for those.
            let host = NSHostingView(rootView: root)
            host.translatesAutoresizingMaskIntoConstraints = false
            let widthConstraint = host.widthAnchor.constraint(equalToConstant: width)
            widthConstraint.priority = .required
            widthConstraint.isActive = true
            host.layoutSubtreeIfNeeded()
            let fitted = host.fittingSize
            widthConstraint.isActive = false
            return fitted.height
            #else
            let controller = UIHostingController(rootView: root)
            controller.view.backgroundColor = .clear
            let target = CGSize(width: width, height: CGFloat.infinity)
            return controller.sizeThatFits(in: target).height
            #endif
        }
    }
}

// MARK: - AppKit sizing cell

#if canImport(AppKit)

/// Cell installed on `ChatMarkdownTableAttachment` so `NSLayoutManager` (which
/// on macOS sizes attachments via `NSTextAttachmentCellProtocol`) gets the
/// real measured table height instead of the default 1×1 placeholder.
final class ChatMarkdownTableAttachmentCell: NSTextAttachmentCell, @unchecked Sendable {
    nonisolated(unsafe) private weak var owner: ChatMarkdownTableAttachment?

    nonisolated init(attachment: ChatMarkdownTableAttachment) {
        self.owner = attachment
        super.init(textCell: "")
    }

    required init(coder: NSCoder) {
        fatalError("ChatMarkdownTableAttachmentCell is not decodable")
    }

    override func cellSize() -> NSSize {
        // Cell-only path (no container/line fragment): give a placeholder.
        // `cellFrame(for:...)` is the path NSLayoutManager actually uses.
        return NSSize(width: 1, height: 1)
    }

    override func cellFrame(
        for textContainer: NSTextContainer,
        proposedLineFragment lineFrag: NSRect,
        glyphPosition position: NSPoint,
        characterIndex charIndex: Int
    ) -> NSRect {
        guard let owner else { return .zero }
        return owner.computeBounds(containerWidth: textContainer.size.width, lineFrag: lineFrag)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        // SwiftUI overlay paints the table; nothing to draw here.
    }

    override func draw(
        withFrame cellFrame: NSRect,
        in controlView: NSView?,
        characterIndex charIndex: Int,
        layoutManager: NSLayoutManager
    ) {
        // SwiftUI overlay paints the table; nothing to draw here.
    }
}

#endif

// MARK: - Storage scan helper

extension NSAttributedString {
    /// Enumerate every `ChatMarkdownTableAttachment` in the storage with its
    /// effective range. Used by the host to inject theme/style after build
    /// and to invalidate layout on width changes.
    func enumerateChatMarkdownTableAttachments(
        _ body: (ChatMarkdownTableAttachment, NSRange) -> Void
    ) {
        let full = NSRange(location: 0, length: length)
        enumerateAttribute(.attachment, in: full, options: []) { value, range, _ in
            guard let attachment = value as? ChatMarkdownTableAttachment else { return }
            body(attachment, range)
        }
    }
}

#endif
