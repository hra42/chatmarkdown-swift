import Foundation

#if canImport(AppKit)
import AppKit
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
#endif

enum PlatformFonts {
    static func body() -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.systemFont(ofSize: NSFont.systemFontSize)
        #else
        return UIFont.preferredFont(forTextStyle: .body)
        #endif
    }

    static func heading(level: Int) -> PlatformFont {
        let size: CGFloat
        switch level {
        case 1: size = 28
        case 2: size = 24
        case 3: size = 20
        default: size = 18
        }
        #if canImport(AppKit)
        return NSFont.boldSystemFont(ofSize: size)
        #else
        return UIFont.systemFont(ofSize: size, weight: .bold)
        #endif
    }

    static func monospaced(size: CGFloat = 14) -> PlatformFont {
        #if canImport(AppKit)
        if let f = NSFont(name: "Menlo", size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #else
        return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #endif
    }

    static func bold(_ font: PlatformFont) -> PlatformFont {
        #if canImport(AppKit)
        return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        #else
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(
            font.fontDescriptor.symbolicTraits.union(.traitBold)
        ) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
        #endif
    }

    static func italic(_ font: PlatformFont) -> PlatformFont {
        #if canImport(AppKit)
        return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        #else
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(
            font.fontDescriptor.symbolicTraits.union(.traitItalic)
        ) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
        #endif
    }
}

enum PlatformColors {
    static var primary: PlatformColor {
        #if canImport(AppKit)
        return NSColor.labelColor
        #else
        return UIColor.label
        #endif
    }

    static var secondary: PlatformColor {
        #if canImport(AppKit)
        return NSColor.secondaryLabelColor
        #else
        return UIColor.secondaryLabel
        #endif
    }

    static var link: PlatformColor {
        #if canImport(AppKit)
        return NSColor.linkColor
        #else
        return UIColor.link
        #endif
    }

    static var codeBackground: PlatformColor {
        #if canImport(AppKit)
        return NSColor(white: 0.5, alpha: 0.12)
        #else
        return UIColor(white: 0.5, alpha: 0.12)
        #endif
    }

    static var inlineCodeBackground: PlatformColor {
        #if canImport(AppKit)
        return NSColor(white: 0.5, alpha: 0.18)
        #else
        return UIColor(white: 0.5, alpha: 0.18)
        #endif
    }

    static var black: PlatformColor {
        #if canImport(AppKit)
        return NSColor.black
        #else
        return UIColor.black
        #endif
    }
}
