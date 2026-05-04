import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

enum TextKitThemeAdapter {
    static func platformColor(_ color: Color) -> PlatformColor {
        #if canImport(AppKit)
        return NSColor(color)
        #else
        return UIColor(color)
        #endif
    }

    static func bodyFont(for theme: ChatMarkdownTheme) -> PlatformFont {
        PlatformFontResolver.resolve(theme.bodyFont, fallback: PlatformFonts.body())
    }

    static func headingFont(level: Int, theme: ChatMarkdownTheme) -> PlatformFont {
        let font = theme.headingFonts[level]
            ?? theme.headingFonts[1]
            ?? .system(size: 28, weight: .bold)
        return PlatformFontResolver.resolve(font, fallback: PlatformFonts.heading(level: level))
    }

    static func codeFont(for theme: ChatMarkdownTheme) -> PlatformFont {
        PlatformFontResolver.resolve(theme.codeFont, fallback: PlatformFonts.monospaced())
    }

    static func inlineCodeFont(for theme: ChatMarkdownTheme) -> PlatformFont {
        PlatformFontResolver.resolve(
            theme.inlineCodeFont,
            fallback: PlatformFonts.monospaced(size: PlatformFonts.body().pointSize)
        )
    }
}

#endif
