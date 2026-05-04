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
        PlatformFonts.body()
    }

    static func headingFont(level: Int, theme: ChatMarkdownTheme) -> PlatformFont {
        PlatformFonts.heading(level: level)
    }

    static func codeFont(for theme: ChatMarkdownTheme) -> PlatformFont {
        PlatformFonts.monospaced()
    }
}

#endif
