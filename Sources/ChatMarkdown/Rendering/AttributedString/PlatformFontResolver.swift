import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) || canImport(UIKit)

// SwiftUI exposes no public bridge from `Font` to `NSFont`/`UIFont`. This
// resolver reflects on the Font's private representation to recover the
// values the library itself produces (`.system(size:weight:design:)`,
// `.system(_:design:)`, `.custom(_:size:)`, modifiers like `.bold()` /
// `.italic()`, and the static text-style values like `.body`). Apple's
// internals are not API: every cast is `as?`-guarded and any unrecognized
// shape falls back to the caller-provided default. In DEBUG, unknown
// shapes trip an assertion so SDK drift surfaces during development
// instead of silently regressing.
enum PlatformFontResolver {
    static func resolve(
        _ font: Font,
        fallback: @autoclosure () -> PlatformFont
    ) -> PlatformFont {
        if let resolved = resolveProvider(font) {
            return resolved
        }
        assertionFailure("PlatformFontResolver: unrecognized Font shape \(font)")
        return fallback()
    }

    private static func resolveProvider(_ font: Font) -> PlatformFont? {
        let mirror = Mirror(reflecting: font)
        guard let provider = child(of: mirror, named: "provider") else { return nil }
        return resolveBase(provider)
    }

    private static func resolveBase(_ providerValue: Any) -> PlatformFont? {
        let providerMirror = Mirror(reflecting: providerValue)
        guard let base = child(of: providerMirror, named: "base") else {
            return nil
        }
        let typeName = String(describing: type(of: base))

        if typeName.contains("SystemProvider") {
            return resolveSystem(base)
        }
        if typeName.contains("TextStyleProvider") {
            return resolveTextStyle(base)
        }
        if typeName.contains("NamedProvider") {
            return resolveNamed(base)
        }
        if typeName.contains("StaticModifierProvider") {
            return resolveStaticModifier(base, typeName: typeName)
        }
        if typeName.contains("ModifierProvider") {
            return resolveModifier(base, typeName: typeName)
        }
        return nil
    }

    // MARK: - SystemProvider: .system(size:weight:design:)

    private static func resolveSystem(_ base: Any) -> PlatformFont? {
        let mirror = Mirror(reflecting: base)
        guard let size = child(of: mirror, named: "size") as? CGFloat else {
            return nil
        }
        let weight = child(of: mirror, named: "weight") as? Font.Weight
        let design = child(of: mirror, named: "design") as? Font.Design
        return makeSystem(size: size, weight: weight, design: design)
    }

    // MARK: - TextStyleProvider: .system(_:design:)

    private static func resolveTextStyle(_ base: Any) -> PlatformFont? {
        let mirror = Mirror(reflecting: base)
        guard let style = child(of: mirror, named: "style") as? Font.TextStyle else {
            return nil
        }
        let design = child(of: mirror, named: "design") as? Font.Design
        let weight = child(of: mirror, named: "weight") as? Font.Weight
        return makeTextStyle(style, design: design, weight: weight)
    }

    // MARK: - NamedProvider: .custom(_:size:)

    private static func resolveNamed(_ base: Any) -> PlatformFont? {
        let mirror = Mirror(reflecting: base)
        guard let name = child(of: mirror, named: "name") as? String,
              let size = child(of: mirror, named: "size") as? CGFloat else {
            return nil
        }
        #if canImport(AppKit)
        if let f = NSFont(name: name, size: size) { return f }
        return NSFont.systemFont(ofSize: size)
        #else
        if let f = UIFont(name: name, size: size) { return f }
        return UIFont.systemFont(ofSize: size)
        #endif
    }

    // MARK: - StaticModifierProvider<…>

    private static func resolveStaticModifier(_ base: Any, typeName: String) -> PlatformFont? {
        // The generic parameter encodes the style: e.g.
        // "StaticModifierProvider<SwiftUI.Font.(unknown context).BoldModifier>"
        // For static text-style values like Font.body, the modifier itself
        // *is* the style — represented via Font.body's static accessor that
        // wraps a TextStyleProvider. In practice Font.body and friends are
        // resolved via TextStyleProvider above, so this branch handles
        // bold/italic style modifiers attached to nothing.
        if typeName.contains("BoldModifier") {
            #if canImport(AppKit)
            return PlatformFonts.bold(NSFont.systemFont(ofSize: NSFont.systemFontSize))
            #else
            return PlatformFonts.bold(UIFont.preferredFont(forTextStyle: .body))
            #endif
        }
        if typeName.contains("ItalicModifier") {
            #if canImport(AppKit)
            return PlatformFonts.italic(NSFont.systemFont(ofSize: NSFont.systemFontSize))
            #else
            return PlatformFonts.italic(UIFont.preferredFont(forTextStyle: .body))
            #endif
        }
        // Some SwiftUI versions wrap the underlying base in a child here too.
        let mirror = Mirror(reflecting: base)
        if let inner = child(of: mirror, named: "base") as? Font {
            return resolveProvider(inner)
        }
        return nil
    }

    // MARK: - ModifierProvider<…>

    private static func resolveModifier(_ base: Any, typeName: String) -> PlatformFont? {
        let mirror = Mirror(reflecting: base)
        guard let inner = child(of: mirror, named: "base") as? Font else {
            return nil
        }
        guard let resolved = resolveProvider(inner) else { return nil }

        if typeName.contains("BoldModifier") {
            return PlatformFonts.bold(resolved)
        }
        if typeName.contains("ItalicModifier") {
            return PlatformFonts.italic(resolved)
        }
        if typeName.contains("WeightModifier") {
            if let weight = child(of: mirror, named: "weight") as? Font.Weight,
               isBoldish(weight) {
                return PlatformFonts.bold(resolved)
            }
            return resolved
        }
        if typeName.contains("MonospacedModifier") {
            return makeMonospaced(resolved)
        }
        // Unknown modifier — preserve the underlying font rather than
        // dropping back to the fallback, since the base resolved cleanly.
        return resolved
    }

    // MARK: - Builders

    private static func makeSystem(
        size: CGFloat,
        weight: Font.Weight?,
        design: Font.Design?
    ) -> PlatformFont {
        #if canImport(AppKit)
        let nsWeight = nsWeight(weight)
        let base: NSFont
        if design == .monospaced {
            base = NSFont.monospacedSystemFont(ofSize: size, weight: nsWeight)
        } else {
            base = NSFont.systemFont(ofSize: size, weight: nsWeight)
        }
        return applyDesign(design, to: base, size: size)
        #else
        let uiWeight = uiWeight(weight)
        let base: UIFont
        if design == .monospaced {
            base = UIFont.monospacedSystemFont(ofSize: size, weight: uiWeight)
        } else {
            base = UIFont.systemFont(ofSize: size, weight: uiWeight)
        }
        return applyDesign(design, to: base, size: size)
        #endif
    }

    private static func makeTextStyle(
        _ style: Font.TextStyle,
        design: Font.Design?,
        weight: Font.Weight?
    ) -> PlatformFont {
        #if canImport(AppKit)
        let size = nsSize(for: style)
        let base: NSFont
        if design == .monospaced {
            base = NSFont.monospacedSystemFont(ofSize: size, weight: nsWeight(weight))
        } else {
            base = NSFont.systemFont(ofSize: size, weight: nsWeight(weight))
        }
        return applyDesign(design, to: base, size: size)
        #else
        let uiStyle = uiTextStyle(style)
        let preferred = UIFont.preferredFont(forTextStyle: uiStyle)
        var result = preferred
        if let weight {
            result = UIFont.systemFont(ofSize: preferred.pointSize, weight: uiWeight(weight))
        }
        return applyDesign(design, to: result, size: result.pointSize)
        #endif
    }

    #if canImport(AppKit)
    private static func applyDesign(_ design: Font.Design?, to font: NSFont, size: CGFloat) -> NSFont {
        guard let design, design != .default else { return font }
        switch design {
        case .monospaced:
            return font // already produced via monospacedSystemFont
        case .serif:
            if let descriptor = font.fontDescriptor.withDesign(.serif) {
                return NSFont(descriptor: descriptor, size: size) ?? font
            }
            return font
        case .rounded:
            if let descriptor = font.fontDescriptor.withDesign(.rounded) {
                return NSFont(descriptor: descriptor, size: size) ?? font
            }
            return font
        case .default:
            return font
        @unknown default:
            return font
        }
    }
    #else
    private static func applyDesign(_ design: Font.Design?, to font: UIFont, size: CGFloat) -> UIFont {
        guard let design, design != .default else { return font }
        let uiDesign: UIFontDescriptor.SystemDesign
        switch design {
        case .monospaced: uiDesign = .monospaced
        case .serif: uiDesign = .serif
        case .rounded: uiDesign = .rounded
        case .default: return font
        @unknown default: return font
        }
        if let descriptor = font.fontDescriptor.withDesign(uiDesign) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return font
    }
    #endif

    private static func makeMonospaced(_ font: PlatformFont) -> PlatformFont {
        #if canImport(AppKit)
        if let descriptor = font.fontDescriptor.withDesign(.monospaced) {
            return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        }
        return NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        #else
        if let descriptor = font.fontDescriptor.withDesign(.monospaced) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
        #endif
    }

    // MARK: - Mirror helpers

    private static func child(of mirror: Mirror, named name: String) -> Any? {
        for (label, value) in mirror.children where label == name {
            return value
        }
        if let superMirror = mirror.superclassMirror {
            return child(of: superMirror, named: name)
        }
        return nil
    }

    // MARK: - Weight helpers

    private static func isBoldish(_ weight: Font.Weight) -> Bool {
        switch weight {
        case .semibold, .bold, .heavy, .black: return true
        default: return false
        }
    }

    #if canImport(AppKit)
    private static func nsWeight(_ weight: Font.Weight?) -> NSFont.Weight {
        guard let weight else { return .regular }
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func nsSize(for style: Font.TextStyle) -> CGFloat {
        // NSFont.preferredFont(forTextStyle:) was introduced in macOS 11.
        if #available(macOS 11.0, *) {
            return NSFont.preferredFont(forTextStyle: nsTextStyle(style)).pointSize
        }
        switch style {
        case .largeTitle: return 26
        case .title: return 22
        case .title2: return 17
        case .title3: return 15
        case .headline: return 13
        case .body: return 13
        case .callout: return 12
        case .subheadline: return 11
        case .footnote: return 10
        case .caption: return 10
        case .caption2: return 10
        @unknown default: return 13
        }
    }

    @available(macOS 11.0, *)
    private static func nsTextStyle(_ style: Font.TextStyle) -> NSFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
    #else
    private static func uiWeight(_ weight: Font.Weight?) -> UIFont.Weight {
        guard let weight else { return .regular }
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
    #endif
}

#endif
