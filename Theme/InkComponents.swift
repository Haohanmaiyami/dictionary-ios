//
//  InkComponents.swift
//  DictionaryApp
//
//  Building blocks shared by every screen of the “Ink & Cinnabar” design.
//

import SwiftUI
import UIKit

// MARK: - Screen header

/// Small red Chinese label on the left (汉俄词典, 翻译…) and an optional control on the right.
struct InkScreenHeader<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(InkFont.chinese(18))
                .tracking(2.6)
                .foregroundStyle(Ink.cinnabar)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: 44)
    }
}

extension InkScreenHeader where Trailing == EmptyView {
    init(label: String) {
        self.init(label: label) { EmptyView() }
    }
}

struct InkInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.system(size: 20))
                .foregroundStyle(Ink.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Конфиденциальность")
    }
}

struct InkLargeTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(InkFont.serif(38, .semibold, relativeTo: .largeTitle))
            .foregroundStyle(Ink.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityAddTraits(.isHeader)
    }
}

struct InkSubtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(InkFont.serif(15, italic: true, relativeTo: .subheadline))
            .foregroundStyle(Ink.inkTertiary)
    }
}

// MARK: - Section label

/// Letter-spaced red caption followed by a hairline, e.g. «НЕДАВНИЕ ———— Вся история».
struct InkSectionLabel<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(InkFont.serif(11.5, .semibold, relativeTo: .caption1))
                .tracking(2.4)
                .foregroundStyle(Ink.cinnabarDeep)
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Ink.line)
                .frame(height: 1)
                .accessibilityHidden(true)
            accessory()
        }
    }
}

extension InkSectionLabel where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - Word row

/// One dictionary word: headword, pinyin and a short translation. Articles
/// from the Russian–Chinese dictionary show the Russian word on top and up to
/// three lines of their Chinese article, as before.
struct InkEntryRow: View {
    let headword: String
    let pinyin: String?
    let translation: String
    let isRussianHeadword: Bool
    var highlight: String? = nil
    var isProminent = false

    init(entry: Entry, highlight: String? = nil, isProminent: Bool = false) {
        headword = entry.displayHeadword
        pinyin = entry.displayPinyin
        translation = InkText.withoutDSLEscapes(entry.previewText)
        isRussianHeadword = entry.isRussianHeadword
        self.highlight = highlight
        self.isProminent = isProminent
    }

    private var isLong: Bool { headword.count > 4 }

    var body: some View {
        HStack(spacing: 14) {
            if isRussianHeadword {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headword)
                        .font(InkFont.serif(20, .semibold, relativeTo: .title3))
                        .foregroundStyle(Ink.ink)
                        .lineLimit(2)
                    Text(InkFont.mixed(translation, size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Ink.inkSecondary)
                        .lineLimit(3)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(headword)
                    .font(InkFont.chinese(isLong ? 18 : (isProminent ? 32 : 26)))
                    .foregroundStyle(Ink.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .truncationMode(.tail)
                    .frame(width: isLong ? 118 : 84, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    if let pinyin, !pinyin.isEmpty {
                        Text(pinyin)
                            .font(InkFont.serif(16, .medium, italic: true))
                            .foregroundStyle(Ink.muted)
                            .lineLimit(1)
                    }
                    Text(highlightedTranslation)
                        .font(InkFont.serif(14.5, relativeTo: .subheadline))
                        .foregroundStyle(Ink.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.mutedSoft)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, isProminent ? 12 : 0)
        .background {
            if isProminent {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Ink.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Ink.lineSoft, lineWidth: 1))
            }
        }
        .overlay(alignment: .bottom) {
            if !isProminent {
                Rectangle().fill(Ink.lineSoft).frame(height: 1)
            }
        }
        .padding(.horizontal, isProminent ? -12 : 0)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var highlightedTranslation: AttributedString {
        var text = InkFont.mixed(translation, size: 14.5, relativeTo: .subheadline)
        guard let needle = highlight?.trimmingCharacters(in: .whitespacesAndNewlines),
              !needle.isEmpty else { return text }
        var start = text.startIndex
        while start < text.endIndex,
              let range = text[start...].range(of: needle, options: [.caseInsensitive]) {
            text[range].backgroundColor = Ink.highlight
            text[range].foregroundColor = Ink.ink
            text[range].font = InkFont.serif(14.5, .semibold, relativeTo: .subheadline)
            start = range.upperBound
        }
        return text
    }
}

// MARK: - Empty and error states

struct InkEmptyState: View {
    let image: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(image)
                .accessibilityHidden(true)
            Text(title)
                .font(InkFont.serif(25, .semibold, relativeTo: .title2))
                .foregroundStyle(Ink.ink)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(InkFont.serif(14.5, relativeTo: .subheadline))
                    .foregroundStyle(Ink.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 290)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Seal

/// Square cinnabar seal with paper-colored characters (译, 等…).
struct InkSeal: View {
    let text: String
    var size: CGFloat = 28
    var rotation: Double = 0

    var body: some View {
        Text(text)
            .font(InkFont.chinese(size * 0.6))
            .foregroundStyle(Ink.sealText)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.14).fill(Ink.cinnabar))
            .rotationEffect(.degrees(rotation))
            .accessibilityHidden(true)
    }
}

// MARK: - Loading placeholders

struct InkSkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Ink.lineSoft)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(dimmed ? 0.45 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { if !reduceMotion { dimmed = true } }
            .accessibilityHidden(true)
    }
}

// MARK: - Copybook grids

/// 米字格: the dashed guide cell used in Chinese copybooks.
struct InkMiZiGrid: View {
    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }
            .stroke(Ink.grid, style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }
        .accessibilityHidden(true)
    }
}

/// 田字格: cross-only guide used on the small character tiles.
struct InkTianZiGrid: View {
    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(origin: .zero, size: geometry.size)
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            }
            .stroke(Ink.grid, style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// Cinnabar outline capsule (Повторить).
struct InkOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InkFont.serif(14, .semibold))
            .foregroundStyle(Ink.cinnabar)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .overlay(Capsule().stroke(Ink.cinnabar, lineWidth: 1.5))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Full-width ink capsule with a small cinnabar seal (Перевести).
struct InkPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InkFont.serif(19, .semibold))
            .foregroundStyle(Ink.onInk)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(Ink.ink))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
            .contentShape(Capsule())
    }
}

// MARK: - Card

extension View {
    /// Paper card with a hairline border used for results and forms.
    func inkCard(padding: CGFloat = 16, dashed: Bool = false) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(dashed ? Color.clear : Ink.card))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Ink.line, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 4] : []))
            )
    }
}
