import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

/// `NSLayoutManager` subclass that paints block-level decorations
/// (blockquote left rules, horizontal rules) inside the layout manager's
/// own `drawBackground(forGlyphRange:at:)` hook.
///
/// Drawing here — instead of from the text view's `draw(_:)` override —
/// keeps decorations correctly z-ordered under text, ties their
/// invalidation to the layout manager's normal redraw path, and ensures
/// layout has been forced for the glyph range about to be drawn (so
/// `boundingRect(forGlyphRange:in:)` returns a sane height even mid-stream).
final class ChatMarkdownLayoutManager: NSLayoutManager {
    /// Updated by `ChatMarkdownTextKitHost.apply(...)` whenever the host
    /// pushes a new theme into the view.
    var chatMarkdownTheme: ChatMarkdownTheme?

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let theme = chatMarkdownTheme,
              let textContainer = self.textContainer(forGlyphAt: glyphsToShow.location, effectiveRange: nil)
                ?? textContainers.first,
              let textStorage = self.textStorage else { return }

        let blockquoteColor = TextKitThemeAdapter.platformColor(theme.blockquoteRuleColor)
        let hrColor = TextKitThemeAdapter.platformColor(theme.horizontalRuleColor)

        ChatMarkdownTextKitDrawing.drawBlockquoteRules(
            glyphsToDraw: glyphsToShow,
            origin: origin,
            layoutManager: self,
            textContainer: textContainer,
            textStorage: textStorage,
            color: blockquoteColor
        )
        ChatMarkdownTextKitDrawing.drawHorizontalRules(
            glyphsToDraw: glyphsToShow,
            origin: origin,
            layoutManager: self,
            textContainer: textContainer,
            textStorage: textStorage,
            color: hrColor
        )
    }
}

#endif
