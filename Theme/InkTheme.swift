//
//  InkTheme.swift
//  DictionaryApp
//
//  “Ink & Cinnabar” design: rice paper, ink and a cinnabar seal.
//  Colors adapt to dark mode; text uses the system serif (New York) for
//  Russian and pinyin, with the bundled Noto Serif SC for Chinese characters.
//

import SwiftUI
import UIKit
import CoreText

// MARK: - Colors

enum Ink {
    static var paper: Color { color(0xF4EEE1, 0x15120F) }
    static var card: Color { color(0xFBF8F1, 0x211C17) }
    static var line: Color { color(0xD9CDB6, 0x3A322A) }
    static var lineSoft: Color { color(0xE0D5C1, 0x2E2822) }
    static var ink: Color { color(0x1E1A16, 0xEDE4D3) }
    static var inkSecondary: Color { color(0x4A4238, 0xCFC3B0) }
    static var inkTertiary: Color { color(0x5C5244, 0xB5A893) }
    static var muted: Color { color(0x6B6052, 0x9C907E) }
    static var mutedSoft: Color { color(0xB3A792, 0x6B6152) }
    static var cinnabar: Color { color(0xB8352A, 0xE0604E) }
    static var cinnabarDeep: Color { color(0x8A3A2E, 0xE07A6A) }
    static var jade: Color { color(0x2F6B47, 0x7DBE93) }
    static var lapis: Color { color(0x24507F, 0x8FB5E3) }
    static var highlight: Color { color(0xF2D3C8, 0x4E2C25) }
    static var segment: Color { color(0xEAE0CC, 0x2A241E) }
    static var grid: Color { color(0xEAD1C8, 0x4A2E28) }
    static var pale: Color { color(0xE3D7C2, 0x3A322A) }
    /// Text drawn on an ink-colored button.
    static var onInk: Color { color(0xF4EEE1, 0x15120F) }
    /// Paper-colored characters carved into a cinnabar seal (same in both themes).
    static let sealText = Color(red: 0xF6 / 255, green: 0xEE / 255, blue: 0xDF / 255)

    nonisolated static func uiColor(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
    }

    private static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: uiColor(light: light, dark: dark))
    }
}

// MARK: - Fonts

enum InkFont {
    /// PostScript names of the bundled Chinese serif faces.
    static let chineseRegular = "NotoSerifCJKsc-Regular"
    static let chineseBold = "NotoSerifCJKsc-Bold"

    /// Registers the Chinese serif faces stored as data assets in the asset
    /// catalog. Missing fonts are not an error: text falls back to the system.
    static func registerBundledFonts() {
        for (asset, name) in [("NotoSerifSC-Regular", chineseRegular), ("NotoSerifSC-Bold", chineseBold)] {
            guard UIFont(name: name, size: 12) == nil,
                  let data = NSDataAsset(name: asset)?.data else { continue }
            let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData)
            if CFArrayGetCount(descriptors) > 0 {
                CTFontManagerRegisterFontDescriptors(descriptors, .process, true, nil)
            }
            // Fallback that registers synchronously from memory.
            if UIFont(name: name, size: 12) == nil,
               let provider = CGDataProvider(data: data as CFData),
               let font = CGFont(provider) {
                CTFontManagerRegisterGraphicsFont(font, nil)
            }
        }
    }

    /// System serif (New York) that takes Chinese glyphs from Noto Serif SC.
    static func uiSerif(size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        var descriptor = system.fontDescriptor
        if italic, let slanted = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = slanted
        }
        if let serif = descriptor.withDesign(.serif) {
            descriptor = serif
        }
        let chineseName = weight.rawValue >= UIFont.Weight.semibold.rawValue ? chineseBold : chineseRegular
        let chinese = UIFontDescriptor(fontAttributes: [.name: chineseName])
        descriptor = descriptor.addingAttributes([.cascadeList: [chinese]])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Serif text that follows Dynamic Type (capped so layouts keep their shape).
    static func serif(_ size: CGFloat, _ weight: UIFont.Weight = .regular,
                      italic: Bool = false, relativeTo style: UIFont.TextStyle = .body) -> Font {
        let scaled = min(UIFontMetrics(forTextStyle: style).scaledValue(for: size), size * 1.6)
        return Font(uiSerif(size: scaled, weight: weight, italic: italic) as CTFont)
    }

    /// Chinese-only labels such as 汉俄词典 and the characters in seals.
    static func uiChinese(size: CGFloat, bold: Bool = true) -> UIFont {
        UIFont(name: bold ? chineseBold : chineseRegular, size: size)
            ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    static func chinese(_ size: CGFloat, bold: Bool = true) -> Font {
        Font(uiChinese(size: size, bold: bold) as CTFont)
    }

    /// Text that mixes Russian or pinyin with Chinese: Chinese characters get
    /// Noto Serif SC, everything else the system serif. iOS does not apply a
    /// custom fallback list to its own serif, so the scripts are split here.
    static func mixed(_ string: String, size: CGFloat, weight: UIFont.Weight = .regular,
                      italic: Bool = false, relativeTo style: UIFont.TextStyle = .body) -> AttributedString {
        var text = AttributedString(string)
        applyFonts(to: &text, from: 0, length: text.unicodeScalars.count,
                   size: size, weight: weight, italic: italic, relativeTo: style)
        return text
    }

    /// Sets fonts on `length` Unicode scalars starting at `offset`, splitting
    /// Chinese and non-Chinese stretches. Other attributes are kept.
    static func applyFonts(to text: inout AttributedString, from offset: Int, length: Int,
                           size: CGFloat, weight: UIFont.Weight, italic: Bool,
                           relativeTo style: UIFont.TextStyle = .body) {
        let scalars = Array(text.unicodeScalars)
        guard offset >= 0, length > 0, offset + length <= scalars.count else { return }
        let scaled = min(UIFontMetrics(forTextStyle: style).scaledValue(for: size), size * 1.6)
        let latin = Font(uiSerif(size: scaled, weight: weight, italic: italic) as CTFont)
        let chineseFont = Font(uiChinese(size: scaled,
                                         bold: weight.rawValue >= UIFont.Weight.semibold.rawValue) as CTFont)
        var start = offset
        let end = offset + length
        while start < end {
            let isHan = isChinese(scalars[start])
            var stop = start + 1
            while stop < end && isChinese(scalars[stop]) == isHan { stop += 1 }
            let lower = text.unicodeScalars.index(text.startIndex, offsetBy: start)
            let upper = text.unicodeScalars.index(lower, offsetBy: stop - start)
            text[lower..<upper].font = isHan ? chineseFont : latin
            start = stop
        }
    }

    static func isChinese(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isIdeographic
            || (0x3000...0x303F).contains(scalar.value)   // CJK punctuation
            || (0xFF00...0xFFEF).contains(scalar.value)   // full-width forms
    }
}

// MARK: - Shared text helpers

enum InkText {
    /// "1 слово", "2 слова", "5 слов".
    static func words(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "\(count) слово" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(count) слова" }
        return "\(count) слов"
    }

    /// DSL escapes such as `\[если\]` are shown as `[если]`.
    static func withoutDSLEscapes(_ text: String) -> String {
        text.replacingOccurrences(of: "\\[", with: "[")
            .replacingOccurrences(of: "\\]", with: "]")
    }
}
