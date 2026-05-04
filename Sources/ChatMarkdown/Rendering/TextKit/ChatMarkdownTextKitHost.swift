import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

// MARK: - Table attachment refresh

/// After every `apply()`, walk the storage and inject the current
/// `theme`/`tableStyle` into each `ChatMarkdownTableAttachment` so the
/// attachment measures with the same SwiftUI tree the overlay paints.
/// The width-keyed height cache stays valid across stable updates; width
/// changes clear it via the host's layout hooks.
@MainActor
fileprivate func refreshTableAttachments(
    in storage: NSTextStorage,
    layoutManager: NSLayoutManager?,
    theme: ChatMarkdownTheme,
    tableStyle: AnyChatMarkdownTableStyle
) {
    storage.enumerateChatMarkdownTableAttachments { attachment, _ in
        attachment.theme = theme
        attachment.tableStyle = tableStyle
    }
    _ = layoutManager
}

// MARK: - macOS

#if canImport(AppKit)

struct ChatMarkdownTextKitHost: NSViewRepresentable {
    let document: ChatMarkdownDocument
    let theme: ChatMarkdownTheme
    var codeBlockStyle: AnyChatMarkdownCodeBlockStyle = AnyChatMarkdownCodeBlockStyle(DefaultChatMarkdownCodeBlockStyle())
    var tableStyle: AnyChatMarkdownTableStyle = AnyChatMarkdownTableStyle(DefaultChatMarkdownTableStyle())

    init(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle? = nil,
        tableStyle: AnyChatMarkdownTableStyle? = nil
    ) {
        self.document = document
        self.theme = theme
        if let codeBlockStyle { self.codeBlockStyle = codeBlockStyle }
        if let tableStyle { self.tableStyle = tableStyle }
    }

    func makeNSView(context: Context) -> ChatMarkdownNSTextView {
        // ChatMarkdownNSTextView's init(frame:) forces TextKit 1; see the
        // convenience-init comment for why.
        let view = ChatMarkdownNSTextView(frame: .zero)
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.isAutomaticLinkDetectionEnabled = true
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)

        ChatMarkdownTextKitHost.apply(
            document: document,
            theme: theme,
            codeBlockStyle: codeBlockStyle,
            tableStyle: tableStyle,
            to: view
        )
        return view
    }

    func updateNSView(_ nsView: ChatMarkdownNSTextView, context: Context) {
        ChatMarkdownTextKitHost.apply(
            document: document,
            theme: theme,
            codeBlockStyle: codeBlockStyle,
            tableStyle: tableStyle,
            to: nsView
        )
    }

    static func apply(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle = AnyChatMarkdownCodeBlockStyle(DefaultChatMarkdownCodeBlockStyle()),
        tableStyle: AnyChatMarkdownTableStyle = AnyChatMarkdownTableStyle(DefaultChatMarkdownTableStyle()),
        to view: ChatMarkdownNSTextView
    ) {
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: theme)
        view.chatMarkdownTheme = theme
        view.chatMarkdownCodeBlockStyle = codeBlockStyle
        view.chatMarkdownTableStyle = tableStyle
        if let storage = view.textStorage {
            ChatMarkdownIncrementalUpdater.apply(
                result: result,
                to: storage,
                previousBlockIDs: view.chatMarkdownBlockIDs,
                previousBlockRanges: view.chatMarkdownBlockRanges
            )
            refreshTableAttachments(
                in: storage,
                layoutManager: view.layoutManager,
                theme: theme,
                tableStyle: tableStyle
            )
        }
        view.chatMarkdownBlockIDs = result.blockIDs
        view.chatMarkdownBlockRanges = result.blockRanges
        view.invalidateIntrinsicContentSize()
        view.needsLayout = true
        view.needsDisplay = true
        view.relayoutChatMarkdownOverlays()
    }
}

final class ChatMarkdownNSTextView: NSTextView, ChatMarkdownPlatformTextViewProtocol {
    private var lastLaidOutContainerWidth: CGFloat = -1
    var chatMarkdownTheme: ChatMarkdownTheme?
    var chatMarkdownCodeBlockStyle: AnyChatMarkdownCodeBlockStyle?
    var chatMarkdownTableStyle: AnyChatMarkdownTableStyle?
    var chatMarkdownBlockIDs: [BlockID] = []
    var chatMarkdownBlockRanges: [NSRange] = []
    let chatMarkdownOverlayManager = ChatMarkdownTextKitOverlayManager()

    convenience override init(frame frameRect: NSRect) {
        // Always force TextKit 1 — modern NSTextView defaults to TextKit 2,
        // which silently disables `NSTextAttachment.attachmentBounds(...)`.
        self.init(usingTextLayoutManager: false)
        self.frame = frameRect
    }

    override init(frame frameRect: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: textContainer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let width = bounds.width > 0 ? bounds.width : NSView.noIntrinsicMetric
        return NSSize(width: width, height: ceil(used.height))
    }

    override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
        relayoutChatMarkdownOverlays()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateIntrinsicContentSize()
        relayoutChatMarkdownOverlays()
    }

    fileprivate func invalidateTableAttachmentsOnWidthChange() {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let storage = textStorage else { return }
        let width = textContainer.size.width
        guard width.isFinite, width > 0 else { return }
        if abs(width - lastLaidOutContainerWidth) < 0.5 { return }
        lastLaidOutContainerWidth = width
        storage.enumerateChatMarkdownTableAttachments { attachment, range in
            attachment.invalidateHeightCache()
            layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
        layoutManager.ensureLayout(for: textContainer)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        ChatMarkdownTextKitDrawing.drawAnnotations(in: self, theme: chatMarkdownTheme)
    }

    func relayoutChatMarkdownOverlays() {
        guard let theme = chatMarkdownTheme,
              let codeBlockStyle = chatMarkdownCodeBlockStyle,
              let tableStyle = chatMarkdownTableStyle else { return }
        invalidateTableAttachmentsOnWidthChange()
        chatMarkdownOverlayManager.relayout(
            in: self,
            codeBlockStyle: codeBlockStyle,
            tableStyle: tableStyle,
            theme: theme
        )
    }

    // MARK: ChatMarkdownPlatformTextViewProtocol

    var cm_textStorage: NSTextStorage? { textStorage }
    var cm_layoutManager: NSLayoutManager? { layoutManager }
    var cm_textContainer: NSTextContainer? { textContainer }
    var cm_textContainerOrigin: NSPoint { textContainerOrigin }

    func cm_addOverlay(_ view: OverlayHostView) {
        addSubview(view)
    }
}

#endif

// MARK: - iOS / visionOS

#if canImport(UIKit)

struct ChatMarkdownTextKitHost: UIViewRepresentable {
    let document: ChatMarkdownDocument
    let theme: ChatMarkdownTheme
    var codeBlockStyle: AnyChatMarkdownCodeBlockStyle = AnyChatMarkdownCodeBlockStyle(DefaultChatMarkdownCodeBlockStyle())
    var tableStyle: AnyChatMarkdownTableStyle = AnyChatMarkdownTableStyle(DefaultChatMarkdownTableStyle())

    init(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle? = nil,
        tableStyle: AnyChatMarkdownTableStyle? = nil
    ) {
        self.document = document
        self.theme = theme
        if let codeBlockStyle { self.codeBlockStyle = codeBlockStyle }
        if let tableStyle { self.tableStyle = tableStyle }
    }

    func makeUIView(context: Context) -> ChatMarkdownUITextView {
        // ChatMarkdownUITextView's init forces TextKit 1; see the
        // convenience-init comment for why.
        let view = ChatMarkdownUITextView(frame: .zero, textContainer: nil)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.dataDetectorTypes = [.link]
        view.adjustsFontForContentSizeCategory = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)

        ChatMarkdownTextKitHost.apply(
            document: document,
            theme: theme,
            codeBlockStyle: codeBlockStyle,
            tableStyle: tableStyle,
            to: view
        )
        return view
    }

    func updateUIView(_ uiView: ChatMarkdownUITextView, context: Context) {
        ChatMarkdownTextKitHost.apply(
            document: document,
            theme: theme,
            codeBlockStyle: codeBlockStyle,
            tableStyle: tableStyle,
            to: uiView
        )
    }

    static func apply(
        document: ChatMarkdownDocument,
        theme: ChatMarkdownTheme,
        codeBlockStyle: AnyChatMarkdownCodeBlockStyle = AnyChatMarkdownCodeBlockStyle(DefaultChatMarkdownCodeBlockStyle()),
        tableStyle: AnyChatMarkdownTableStyle = AnyChatMarkdownTableStyle(DefaultChatMarkdownTableStyle()),
        to view: ChatMarkdownUITextView
    ) {
        let result = ChatMarkdownTextStorageBuilder.buildWithIndex(document: document, theme: theme)
        view.chatMarkdownTheme = theme
        view.chatMarkdownCodeBlockStyle = codeBlockStyle
        view.chatMarkdownTableStyle = tableStyle
        ChatMarkdownIncrementalUpdater.apply(
            result: result,
            to: view.textStorage,
            previousBlockIDs: view.chatMarkdownBlockIDs,
            previousBlockRanges: view.chatMarkdownBlockRanges
        )
        refreshTableAttachments(
            in: view.textStorage,
            layoutManager: view.layoutManager,
            theme: theme,
            tableStyle: tableStyle
        )
        view.chatMarkdownBlockIDs = result.blockIDs
        view.chatMarkdownBlockRanges = result.blockRanges
        view.invalidateIntrinsicContentSize()
        view.setNeedsLayout()
        view.setNeedsDisplay()
        view.relayoutChatMarkdownOverlays()
    }
}

final class ChatMarkdownUITextView: UITextView, ChatMarkdownPlatformTextViewProtocol {
    private var lastLaidOutContainerWidth: CGFloat = -1
    var chatMarkdownTheme: ChatMarkdownTheme?
    var chatMarkdownCodeBlockStyle: AnyChatMarkdownCodeBlockStyle?
    var chatMarkdownTableStyle: AnyChatMarkdownTableStyle?
    var chatMarkdownBlockIDs: [BlockID] = []
    var chatMarkdownBlockRanges: [NSRange] = []
    let chatMarkdownOverlayManager = ChatMarkdownTextKitOverlayManager()

    convenience override init(frame: CGRect, textContainer: NSTextContainer?) {
        // Force TextKit 1 — UITextView defaults to TextKit 2 in iOS 16+,
        // which doesn't dispatch to `NSTextAttachment.attachmentBounds(...)`.
        self.init(usingTextLayoutManager: false)
        self.frame = frame
        // textContainer arg is ignored intentionally; the TextKit 1 init
        // creates its own.
        _ = textContainer
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric
        let target = CGSize(width: bounds.width > 0 ? bounds.width : .greatestFiniteMagnitude,
                            height: .greatestFiniteMagnitude)
        let fitted = sizeThatFits(target)
        return CGSize(width: width, height: ceil(fitted.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
        relayoutChatMarkdownOverlays()
    }

    fileprivate func invalidateTableAttachmentsOnWidthChange() {
        let layoutManager = self.layoutManager
        let textContainer = self.textContainer
        let storage = textStorage
        let width = textContainer.size.width
        guard width.isFinite, width > 0 else { return }
        if abs(width - lastLaidOutContainerWidth) < 0.5 { return }
        lastLaidOutContainerWidth = width
        storage.enumerateChatMarkdownTableAttachments { attachment, range in
            attachment.invalidateHeightCache()
            layoutManager.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        }
        layoutManager.ensureLayout(for: textContainer)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        ChatMarkdownTextKitDrawing.drawAnnotations(in: self, theme: chatMarkdownTheme)
    }

    func relayoutChatMarkdownOverlays() {
        guard let theme = chatMarkdownTheme,
              let codeBlockStyle = chatMarkdownCodeBlockStyle,
              let tableStyle = chatMarkdownTableStyle else { return }
        invalidateTableAttachmentsOnWidthChange()
        chatMarkdownOverlayManager.relayout(
            in: self,
            codeBlockStyle: codeBlockStyle,
            tableStyle: tableStyle,
            theme: theme
        )
    }

    // MARK: ChatMarkdownPlatformTextViewProtocol

    var cm_textStorage: NSTextStorage? { textStorage }
    var cm_layoutManager: NSLayoutManager? { layoutManager }
    var cm_textContainer: NSTextContainer? { textContainer }
    var cm_textContainerInsetUI: UIEdgeInsets { textContainerInset }

    func cm_addOverlay(_ view: OverlayHostView) {
        addSubview(view)
    }
}

#endif

#endif
