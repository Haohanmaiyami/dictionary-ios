//
//  EntryDetailView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//


import SwiftUI

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
        (currentEntry.isRussianHeadword ? currentEntry.previewText : (currentEntry.ru ?? "Без перевода"))
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var cleanedExamples: String {
        (currentEntry.examples ?? "Примеры отсутствуют")
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                VStack(spacing: 8) {
                    Text(currentEntry.displayHeadword)
                        .font(.system(size: 42, weight: .bold))

                    if let pinyin = currentEntry.displayPinyin, !pinyin.isEmpty {
                        Text(pinyin)
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                
                HStack {
                    Spacer()

                    Button {
                        favoritesStore.toggle(currentEntry)
                    } label: {
                        Image(systemName:
                            favoritesStore.contains(currentEntry)
                            ? "star.fill"
                            : "star"
                        )
                        .font(.title2)
                        .foregroundColor(.yellow)
                    }
                }

                if let article = currentEntry.article {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Перевод")
                            .font(.headline)

                        ForEach(Array(article.rows.enumerated()), id: \.offset) { index, row in
                            DictionaryArticleRowView(row: row, openReference: requestReference)
                                .accessibilityIdentifier("dictionary-article-row-\(index)")
                        }

                        if referenceRequest != nil {
                            ProgressView("Открываю статью…")
                                .font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                } else {
                    // Older server responses and saved entries remain readable.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Перевод")
                            .font(.headline)
                        Text(cleanedTranslation)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if !currentEntry.isRussianHeadword, let examples = currentEntry.examples,
                       !examples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Примеры")
                                .font(.headline)
                            Text(cleanedExamples)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                if !currentEntry.isRussianHeadword, let hanzi = currentEntry.hanzi, !hanzi.isEmpty {
                    StrokeOrderSection(characters: StrokeOrderContent.characters(in: hanzi))
                        // Reset selection if a fetched headword or entry changes.
                        .id("\(currentEntry.id):\(hanzi)")
                }

                Spacer(minLength: 20)
            }
            .padding()
        }

        .navigationTitle("Слово")
        .navigationBarTitleDisplayMode(.inline)
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
        DictionaryArticleRenderer.paragraph(row: row, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !row.text.isEmpty || row.number != nil {
                Text(paragraph)
                    .font(.body)
                    .fontWeight(row.isEmphasized ? .semibold : .regular)
                    .foregroundStyle(row.kind == .example ? Color.blue : Color.primary)
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
                    .foregroundStyle(.blue)
                    .underline()
                }
            }
        }
        .padding(.leading, CGFloat(row.indentation))
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
