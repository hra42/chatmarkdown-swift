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

enum ChatMarkdownTextKitDrawing {
    @MainActor
    static func drawAnnotations(in textView: _PlatformTextView, theme: ChatMarkdownTheme?) {
        guard let theme else { return }
        #if canImport(AppKit)
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let textStorage = textView.textStorage else { return }
        let inset = CGPoint(x: textView.textContainerInset.width, y: textView.textContainerInset.height)
        #else
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let textStorage = textView.textStorage
        let inset = CGPoint(x: textView.textContainerInset.left, y: textView.textContainerInset.top)
        #endif

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let blockquoteColor = TextKitThemeAdapter.platformColor(theme.blockquoteRuleColor)
        let hrColor = TextKitThemeAdapter.platformColor(theme.horizontalRuleColor)

        textStorage.enumerateAttribute(.chatMarkdownBlockquoteRule, in: fullRange, options: []) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let ruleRect = CGRect(
                x: inset.x + 2,
                y: inset.y + usedRect.minY,
                width: 3,
                height: max(usedRect.height, 1)
            )
            blockquoteColor.setFill()
            #if canImport(AppKit)
            NSBezierPath(rect: ruleRect).fill()
            #else
            UIBezierPath(rect: ruleRect).fill()
            #endif
        }

        textStorage.enumerateAttribute(.chatMarkdownHorizontalRule, in: fullRange, options: []) { value, range, _ in
            guard value != nil else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let lineRect = CGRect(
                x: inset.x,
                y: inset.y + usedRect.midY - 0.5,
                width: textContainer.size.width,
                height: 1
            )
            hrColor.setFill()
            #if canImport(AppKit)
            NSBezierPath(rect: lineRect).fill()
            #else
            UIBezierPath(rect: lineRect).fill()
            #endif
        }
    }
}

#endif
