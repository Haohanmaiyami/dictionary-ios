//
//  EntryDetailView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//


import SwiftUI
import UIKit

struct EntryDetailView: View {
    let entry: Entry
    
    @State private var fullEntry: Entry?
    @State private var isLoading = false
    @State private var referenceRequest: String?
    @State private var referencedEntry: Entry?
    @State private var isShowingReference = false
    @State private var referenceError: String?
    
    @ObservedObject private var favoritesStore = FavoritesStore.shared

    private var currentEntry: Entry {
        fullEntry ?? entry
    }
    
    private var cleanedTranslation: String {
        InkText.withoutDSLEscapes(currentEntry.isRussianHeadword ? currentEntry.previewText : (currentEntry.ru ?? "Без перевода"))
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var cleanedExamples: String {
        InkText.withoutDSLEscapes(currentEntry.examples ?? "Примеры отсутствуют")
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFavorite: Bool {
        favoritesStore.contains(currentEntry)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let article = currentEntry.article {
                    VStack(alignment: .leading, spacing: 10) {
                        InkSectionLabel(title: "Словарная статья")

                        ForEach(Array(article.rows.enumerated()), id: \.offset) { index, row in
                            DictionaryArticleRowView(row: row, openReference: requestReference)
                                .accessibilityIdentifier("dictionary-article-row-\(index)")
                        }

                        if referenceRequest != nil {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(Ink.cinnabar)
                                Text("Открываю статью…")
                                    .font(InkFont.serif(13.5, relativeTo: .footnote))
                                    .foregroundStyle(Ink.inkTertiary)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Capsule().fill(Ink.card))
                            .overlay(Capsule().stroke(Ink.line, lineWidth: 1))
                            .padding(.top, 6)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Older server responses and saved entries remain readable.
                    VStack(alignment: .leading, spacing: 8) {
                        InkSectionLabel(title: "Перевод")
                        Text(InkFont.mixed(cleanedTranslation, size: 16))
                            .lineSpacing(3)
                            .foregroundStyle(Ink.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !currentEntry.isRussianHeadword, let examples = currentEntry.examples,
                       !examples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            InkSectionLabel(title: "Примеры")
                            Text(InkFont.mixed(cleanedExamples, size: 17))
                                .lineSpacing(4)
                                .foregroundStyle(Ink.lapis)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
        }
        .background(Ink.paper.ignoresSafeArea())
        .navigationTitle("Слово")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesStore.toggle(currentEntry)
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(Ink.cinnabar)
                }
                .accessibilityLabel(isFavorite ? "Убрать из избранного" : "Добавить в избранное")
            }
        }
        .task {
            HistoryStore.shared.add(entry)
            await loadFullEntry()
        }
        .task(id: referenceRequest) {
            guard let target = referenceRequest else { return }
            await openReference(target)
        }
        .navigationDestination(isPresented: $isShowingReference) {
            if let referencedEntry {
                EntryDetailView(entry: referencedEntry)
            }
        }
        .alert("Не удалось открыть статью", isPresented: Binding(
            get: { referenceError != nil },
            set: { if !$0 { referenceError = nil } }
        )) {
            Button("ОК", role: .cancel) { referenceError = nil }
        } message: {
            Text(referenceError ?? "")
        }
    }

    /// The word itself, its pinyin and the stroke-order animation.
    /// Russian headwords (Russian–Chinese articles) show the word only.
    @ViewBuilder
    private var header: some View {
        let hanzi = currentEntry.isRussianHeadword
            ? ""
            : (currentEntry.hanzi ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let characters = StrokeOrderContent.characters(in: hanzi)
        let pinyin = currentEntry.displayPinyin.flatMap { $0.isEmpty ? nil : $0 }
        let headword = currentEntry.displayHeadword

        VStack(alignment: .leading, spacing: 14) {
            // Show the headword as text when the tiles cannot represent it
            // exactly (no Han characters, punctuation or Latin letters inside).
            if characters.isEmpty || (characters.count > 1 && characters.joined() != hanzi) {
                Text(InkFont.mixed(headword.isEmpty ? "—" : headword, size: characters.isEmpty ? 40 : 26,
                                   weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if characters.isEmpty {
                if let pinyin {
                    Text(pinyin)
                        .font(InkFont.serif(26, .semibold, italic: true, relativeTo: .title1))
                        .foregroundStyle(Ink.ink)
                }
            } else {
                StrokeOrderSection(characters: characters, pinyin: pinyin)
                    // Reset selection if a fetched headword or entry changes.
                    .id("\(currentEntry.id):\(hanzi)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadFullEntry() async {
        isLoading = true

        do {
            let loaded = try await APIService.shared.fetchEntry(id: entry.id)
            try Task.checkCancellation()
            fullEntry = loaded
            favoritesStore.refreshIfSaved(loaded)
            HistoryStore.shared.add(loaded)
        } catch {
            // Keep showing search result data if full entry loading fails.
        }

        isLoading = false
    }

    private func requestReference(_ target: String) {
        guard referenceRequest == nil else { return }
        referenceError = nil
        referenceRequest = target
    }

    private func openReference(_ target: String) async {
        defer { if referenceRequest == target { referenceRequest = nil } }
        do {
            let found = try await APIService.shared.fetchReferencedEntry(target: target)
            try Task.checkCancellation()
            guard found.id != currentEntry.id else {
                referenceError = "Эта ссылка ведёт на текущую статью."
                return
            }
            referencedEntry = found
            isShowingReference = true
        } catch is CancellationError {
            // Leaving the screen cancels the lookup without opening another screen.
        } catch let error as DictionaryReferenceError {
            referenceError = error.localizedDescription
        } catch {
            if !Task.isCancelled {
                referenceError = NetworkErrorPresentation.message(for: error)
            }
        }
    }
}

private struct DictionaryArticleRowView: View {
    let row: DictionaryArticleRow
    let openReference: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var paragraph: AttributedString {
        InkArticleStyle.styled(
            DictionaryArticleRenderer.paragraph(row: row, colorScheme: colorScheme),
            row: row
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !row.text.isEmpty || row.number != nil {
                Text(paragraph)
                    .font(InkFont.serif(16, row.isEmphasized ? .semibold : .regular))
                    .lineSpacing(3)
                    .foregroundStyle(row.kind == .example ? Ink.lapis : Ink.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "dictionary-reference", url.host == "entry",
                              let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                .queryItems?.first(where: { $0.name == "target" })?.value,
                              row.references.contains(where: { $0.target == target }) else {
                            return .discarded
                        }
                        openReference(target)
                        return .handled
                    })
            }

            ForEach(Array(row.references.enumerated()), id: \.offset) { index, reference in
                if DictionaryArticleRenderer.referenceRanges(in: row)[index] == nil {
                    Button(reference.label.isEmpty ? reference.target : reference.label) {
                        openReference(reference.target)
                    }
                    .buttonStyle(.plain)
                    .font(InkFont.serif(16, .semibold))
                    .foregroundStyle(Ink.cinnabar)
                    .underline()
                }
            }
        }
        .padding(.leading, CGFloat(row.indentation))
    }
}

/// Visual layer on top of the renderer's output. Text, links and their
/// ranges come from `DictionaryArticleRenderer` unchanged; this only sets
/// fonts, colours the number and links, and hides DSL escape backslashes.
private enum InkArticleStyle {
    static func styled(_ source: AttributedString, row: DictionaryArticleRow) -> AttributedString {
        var text = source
        let prefixLength = row.numberPrefix.unicodeScalars.count

        // Fonts: the renderer's bold/italic for each formatted run; Chinese
        // characters in Noto Serif SC, Russian and pinyin in the system serif.
        let total = text.unicodeScalars.count
        let baseWeight: UIFont.Weight = row.isEmphasized ? .semibold : .regular
        var appliedRuns = false
        if let runs = row.runs {
            let expected = prefixLength + runs.reduce(0) { $0 + $1.text.unicodeScalars.count }
            if total == expected {
                var offset = prefixLength
                for run in runs {
                    let length = run.text.unicodeScalars.count
                    if length > 0 {
                        InkFont.applyFonts(to: &text, from: offset, length: length, size: 16,
                                           weight: run.bold ? .bold : baseWeight, italic: run.italic)
                    }
                    offset += length
                }
                appliedRuns = true
            }
        }
        if !appliedRuns, total > prefixLength {
            InkFont.applyFonts(to: &text, from: prefixLength, length: total - prefixLength,
                               size: 16, weight: baseWeight, italic: false)
        }

        // Sense number (“3) ”, “IV) ”) in bold cinnabar.
        if prefixLength > 0, text.unicodeScalars.count >= prefixLength {
            let end = text.unicodeScalars.index(text.startIndex, offsetBy: prefixLength)
            text[text.startIndex..<end].foregroundColor = Ink.cinnabar
            text[text.startIndex..<end].font = InkFont.serif(16, .bold)
        }

        // Cross-references in cinnabar (they stay underlined links).
        var linkSpans: [(offset: Int, length: Int)] = []
        for run in text.runs where run.link != nil {
            let offset = text.unicodeScalars.distance(from: text.startIndex, to: run.range.lowerBound)
            let length = text.unicodeScalars.distance(from: run.range.lowerBound, to: run.range.upperBound)
            linkSpans.append((offset, length))
        }
        for span in linkSpans {
            let lower = text.unicodeScalars.index(text.startIndex, offsetBy: span.offset)
            let upper = text.unicodeScalars.index(lower, offsetBy: span.length)
            text[lower..<upper].foregroundColor = Ink.cinnabar
        }

        // `\[если\]` → `[если]`.
        for token in ["\\[", "\\]"] {
            while let range = text.range(of: token) {
                let next = text.unicodeScalars.index(after: range.lowerBound)
                text.removeSubrange(range.lowerBound..<next)
            }
        }
        return text
    }
}

// BEGIN OFFLINE ARTICLE RENDERER
// This renderer is also compiled by Development/verify-articles.py so tests
// exercise the exact attributed text used by the app, without launching it.
enum DictionaryArticleRenderer {
    static func referenceRanges(in row: DictionaryArticleRow) -> [Range<String.Index>?] {
        var searchStart = row.text.startIndex
        return row.references.map { reference in
            let label = reference.label.isEmpty ? reference.target : reference.label
            let available = searchStart..<row.text.endIndex
            let range = row.text.range(of: label, range: available) ??
                row.text.range(of: reference.target, range: available)
            if let range { searchStart = range.upperBound }
            return range
        }
    }

    static func color(_ color: DictionaryInlineColor, scheme: ColorScheme) -> Color {
        // Darker foregrounds on light article cards; brighter ones in dark mode.
        // Unstyled text continues to inherit Color.primary or example blue.
        switch (color, scheme) {
        case (.green, .dark): return Color(red: 0.40, green: 0.85, blue: 0.50)
        case (.green, _): return Color(red: 0.08, green: 0.40, blue: 0.19)
        case (.blue, .dark): return Color(red: 0.43, green: 0.70, blue: 0.98)
        case (.blue, _): return Color(red: 0.10, green: 0.39, blue: 0.65)
        case (.red, .dark): return Color(red: 1.00, green: 0.45, blue: 0.45)
        case (.red, _): return Color(red: 0.68, green: 0.17, blue: 0.17)
        case (.gray, .dark): return Color(red: 0.70, green: 0.70, blue: 0.72)
        case (.gray, _): return Color(red: 0.40, green: 0.40, blue: 0.42)
        case (.primary, _): return .primary
        case (.brown, .dark): return Color(red: 0.88, green: 0.65, blue: 0.43)
        case (.brown, _): return Color(red: 0.48, green: 0.27, blue: 0.12)
        case (.violet, .dark): return Color(red: 0.80, green: 0.60, blue: 0.98)
        case (.violet, _): return Color(red: 0.48, green: 0.22, blue: 0.67)
        case (.crimson, .dark): return Color(red: 1.00, green: 0.48, blue: 0.62)
        case (.crimson, _): return Color(red: 0.68, green: 0.10, blue: 0.25)
        }
    }

    static func paragraph(row: DictionaryArticleRow, colorScheme: ColorScheme) -> AttributedString {
        var text = AttributedString()
        if let runs = row.runs {
            for run in runs {
                var part = AttributedString(run.text)
                var font = Font.body.weight(row.isEmphasized ? .semibold : .regular)
                if run.bold { font = font.bold() }
                if run.italic { font = font.italic() }
                part.font = font
                if run.underline { part.underlineStyle = .single }
                if let runColor = run.color {
                    part.foregroundColor = color(runColor, scheme: colorScheme)
                }
                text += part
            }
        } else {
            text = AttributedString(row.text)
        }

        // Resolve against source text, then map its exact indices into the
        // attributed text. Styling never changes the label or reference target.
        for (reference, sourceRange) in zip(row.references, referenceRanges(in: row)) {
            guard let sourceRange,
                  let lower = AttributedString.Index(sourceRange.lowerBound, within: text),
                  let upper = AttributedString.Index(sourceRange.upperBound, within: text) else { continue }
            var components = URLComponents()
            components.scheme = "dictionary-reference"
            components.host = "entry"
            components.queryItems = [URLQueryItem(name: "target", value: reference.target)]
            let range = lower..<upper
            text[range].link = components.url
            text[range].underlineStyle = .single
            text[range].foregroundColor = color(.blue, scheme: colorScheme)
        }
        // Source run offsets never include numbering.
        return AttributedString(row.numberPrefix) + text
    }
}
// END OFFLINE ARTICLE RENDERER
