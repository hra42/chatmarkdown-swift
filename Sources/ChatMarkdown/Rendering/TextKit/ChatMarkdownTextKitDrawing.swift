import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

#if canImport(AppKit)
typealias _PlatformTextView = NSTextView
#else
typealias _PlatformTextView = UITextView
#endif

#if canImport(AppKit)
typealias _PlatformColor = NSColor
#else
typealias _PlatformColor = UIColor
#endif

/// Geometry helpers shared by `ChatMarkdownLayoutManager.drawBackground(...)`.
/// `origin` is the textContainer origin in view coordinates as TextKit passes
/// it to `drawBackground(forGlyphRange:at:)` — it already accounts for
/// `textContainerInset`, so callers must not add the inset again.
enum ChatMarkdownTextKitDrawing {
    static func drawBlockquoteRules(
        glyphsToDraw: NSRange,
        origin: CGPoint,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        textStorage: NSTextStorage,
        color: _PlatformColor
    ) {
        let charsToDraw = layoutManager.characterRange(forGlyphRange: glyphsToDraw, actualGlyphRange: nil)
        textStorage.enumerateAttribute(.chatMarkdownBlockquoteRule, in: charsToDraw, options: []) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let paragraphStyle = textStorage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
            let headIndent = paragraphStyle?.headIndent ?? 0
            let ruleGap: CGFloat = 6
            let ruleWidth: CGFloat = 3
            let ruleX = origin.x + max(0, headIndent - ruleGap)
            let ruleRect = CGRect(
                x: ruleX,
                y: origin.y + usedRect.minY,
                width: ruleWidth,
                height: max(usedRect.height, 1)
            )
            color.setFill()
            #if canImport(AppKit)
            NSBezierPath(rect: ruleRect).fill()
            #else
            UIBezierPath(rect: ruleRect).fill()
            #endif
        }
    }

    static func drawHorizontalRules(
        glyphsToDraw: NSRange,
        origin: CGPoint,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        textStorage: NSTextStorage,
        color: _PlatformColor
    ) {
        let charsToDraw = layoutManager.characterRange(forGlyphRange: glyphsToDraw, actualGlyphRange: nil)
        textStorage.enumerateAttribute(.chatMarkdownHorizontalRule, in: charsToDraw, options: []) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let lineRect = CGRect(
                x: origin.x,
                y: origin.y + usedRect.midY - 0.5,
                width: textContainer.size.width,
                height: 1
            )
            color.setFill()
            #if canImport(AppKit)
            NSBezierPath(rect: lineRect).fill()
            #else
            UIBezierPath(rect: lineRect).fill()
            #endif
        }
    }
}

#endif
