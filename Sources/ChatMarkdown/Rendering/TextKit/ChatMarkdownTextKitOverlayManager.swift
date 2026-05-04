import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

// MARK: - Slot model

struct ChatMarkdownOverlaySlot {
    let range: NSRange
    let payload: ChatMarkdownAttachmentSlotPayload
}

enum ChatMarkdownOverlaySlotScanner {
    /// Returns the contiguous slot ranges in `storage`. For code blocks, the
    /// returned range covers ONLY the leading attachment character (`\u{FFFC}`)
    /// — the SwiftUI overlay sits over that one-character rect (which the
    /// layout manager places on its own line, since it has paragraph spacing).
    /// For tables, the range covers the slot character plus all reserved
    /// newlines so the overlay covers the full reserved height.
    static func scan(_ storage: NSAttributedString) -> [ChatMarkdownOverlaySlot] {
        var slots: [ChatMarkdownOverlaySlot] = []
        let full = NSRange(location: 0, length: storage.length)
        storage.enumerateAttribute(.chatMarkdownAttachmentSlot, in: full, options: []) { value, range, _ in
            guard let box = value as? ChatMarkdownAttachmentSlotBox else { return }
            // Coalesce adjacent slot runs that share identity (the table
            // payload box is reused across the slot char + reserved newlines).
            if let last = slots.last,
               last.range.location + last.range.length == range.location,
               last.payload == box.payload {
                let merged = NSRange(location: last.range.location,
                                     length: last.range.length + range.length)
                slots[slots.count - 1] = ChatMarkdownOverlaySlot(range: merged, payload: box.payload)
            } else {
                slots.append(ChatMarkdownOverlaySlot(range: range, payload: box.payload))
            }
        }
        return slots
    }
}

// MARK: - Overlay manager

#if canImport(AppKit)
typealias OverlayHostView = NSView
#else
typealias OverlayHostView = UIView
#endif

@MainActor
final class ChatMarkdownTextKitOverlayManager {
    /// One overlay subview per slot, indexed positionally across passes.
    private(set) var overlayViews: [OverlayHostView] = []

    func relayout(
        in textView: ChatMarkdownPlatformTextViewProtocol,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) {
        guard let storage = textView.cm_textStorage,
              let layoutManager = textView.cm_layoutManager,
              let textContainer = textView.cm_textContainer else {
            removeAllOverlays()
            return
        }

        let slots = ChatMarkdownOverlaySlotScanner.scan(storage)

        // Reconcile overlay subview count with slot count.
        while overlayViews.count > slots.count {
            let v = overlayViews.removeLast()
            v.removeFromSuperview()
        }

        layoutManager.ensureLayout(for: textContainer)

        for (i, slot) in slots.enumerated() {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: slot.range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // Overlays are block-level chrome — span the full text container
            // width regardless of the glyph's measured advance (\u{FFFC} or a
            // newline run is narrow on its own).
            let containerWidth = textContainer.size.width
            if containerWidth.isFinite, containerWidth > 0 {
                rect.origin.x = 0
                rect.size.width = containerWidth
            }

            // Translate from text-container space to view space.
            #if canImport(AppKit)
            let inset = textView.cm_textContainerOrigin
            rect.origin.x += inset.x
            rect.origin.y += inset.y
            #else
            let inset = textView.cm_textContainerInsetUI
            rect.origin.x += inset.left
            rect.origin.y += inset.top
            #endif

            if i < overlayViews.count {
                updateOverlay(overlayViews[i],
                              slot: slot,
                              frame: rect,
                              codeBlockStyle: codeBlockStyle,
                              tableStyle: tableStyle,
                              theme: theme)
            } else {
                let v = makeOverlay(slot: slot,
                                    frame: rect,
                                    codeBlockStyle: codeBlockStyle,
                                    tableStyle: tableStyle,
                                    theme: theme)
                textView.cm_addOverlay(v)
                overlayViews.append(v)
            }
        }
    }

    func removeAllOverlays() {
        for v in overlayViews { v.removeFromSuperview() }
        overlayViews.removeAll()
    }

    // MARK: - Overlay construction

    private func makeOverlay(
        slot: ChatMarkdownOverlaySlot,
        frame: CGRect,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) -> OverlayHostView {
        let view = makeHostView(for: slot,
                                codeBlockStyle: codeBlockStyle,
                                tableStyle: tableStyle,
                                theme: theme)
        view.frame = frame
        return view
    }

    private func updateOverlay(
        _ view: OverlayHostView,
        slot: ChatMarkdownOverlaySlot,
        frame: CGRect,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) {
        // Rebuild rootView each pass so style/payload changes propagate.
        replaceRootView(in: view,
                        slot: slot,
                        codeBlockStyle: codeBlockStyle,
                        tableStyle: tableStyle,
                        theme: theme)
        view.frame = frame
    }

    // MARK: - Platform hosting

    #if canImport(AppKit)
    private func makeHostView(
        for slot: ChatMarkdownOverlaySlot,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) -> NSView {
        let root = makeRootView(slot: slot,
                                codeBlockStyle: codeBlockStyle,
                                tableStyle: tableStyle,
                                theme: theme)
        let host = NSHostingView(rootView: root)
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = []
        return host
    }

    private func replaceRootView(
        in view: NSView,
        slot: ChatMarkdownOverlaySlot,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) {
        guard let host = view as? NSHostingView<AnyView> else { return }
        host.rootView = makeRootView(slot: slot,
                                     codeBlockStyle: codeBlockStyle,
                                     tableStyle: tableStyle,
                                     theme: theme)
    }
    #else
    private func makeHostView(
        for slot: ChatMarkdownOverlaySlot,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) -> UIView {
        let root = makeRootView(slot: slot,
                                codeBlockStyle: codeBlockStyle,
                                tableStyle: tableStyle,
                                theme: theme)
        let controller = UIHostingController(rootView: root)
        controller.view.backgroundColor = .clear
        let container = ChatMarkdownOverlayContainerView(controller: controller)
        return container
    }

    private func replaceRootView(
        in view: UIView,
        slot: ChatMarkdownOverlaySlot,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) {
        guard let container = view as? ChatMarkdownOverlayContainerView else { return }
        container.controller.rootView = makeRootView(slot: slot,
                                                     codeBlockStyle: codeBlockStyle,
                                                     tableStyle: tableStyle,
                                                     theme: theme)
    }
    #endif

    private func makeRootView(
        slot: ChatMarkdownOverlaySlot,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle,
        tableStyle: AnyChatMarkdownTableStyle,
        theme: ChatMarkdownTheme
    ) -> AnyView {
        // codeBlockStyle is intentionally unused in this phase: a fully
        // user-supplied ChatMarkdownCodeBlockStyle would paint over the
        // selectable text. The TextKit renderer always uses the built-in
        // chrome-only view; user styles still apply on the SwiftUI renderer.
        _ = codeBlockStyle
        switch slot.payload {
        case .codeBlock(let language, let code, _):
            return AnyView(
                TextKitCodeBlockChromeView(language: language, code: code, theme: theme)
            )
        case .table(let headers, let rows, let alignments):
            let renderedHeaders = headers.map {
                InlineAttributedStringBuilder.build($0, theme: theme, baseFont: theme.bodyFont)
            }
            let renderedRows = rows.map { row in
                row.map {
                    InlineAttributedStringBuilder.build($0, theme: theme, baseFont: theme.bodyFont)
                }
            }
            let configuration = ChatMarkdownTableConfiguration(
                headers: renderedHeaders,
                rows: renderedRows,
                alignments: alignments
            )
            return AnyView(tableStyle.makeBody(configuration: configuration))
        }
    }
}

#if canImport(UIKit)
final class ChatMarkdownOverlayContainerView: UIView {
    let controller: UIHostingController<AnyView>

    init(controller: UIHostingController<AnyView>) {
        self.controller = controller
        super.init(frame: .zero)
        backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
#endif

// MARK: - Chrome-only code block view

struct TextKitCodeBlockChromeView: View {
    let language: String?
    let code: String
    let theme: ChatMarkdownTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(.caption.monospaced())
                    .foregroundStyle(theme.secondaryTextColor)
                Spacer()
                Button {
                    Pasteboard.copy(code)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryTextColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.codeBackground.opacity(0.5))

            Spacer(minLength: 0)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.codeBackground, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(true)
    }
}

// MARK: - Platform abstraction over the text view

@MainActor
protocol ChatMarkdownPlatformTextViewProtocol: AnyObject {
    var cm_textStorage: NSTextStorage? { get }
    var cm_layoutManager: NSLayoutManager? { get }
    var cm_textContainer: NSTextContainer? { get }
    #if canImport(AppKit)
    var cm_textContainerOrigin: NSPoint { get }
    #else
    var cm_textContainerInsetUI: UIEdgeInsets { get }
    #endif
    func cm_addOverlay(_ view: OverlayHostView)
}

#endif
