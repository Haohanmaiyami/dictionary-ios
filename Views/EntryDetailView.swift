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
    
    @ObservedObject private var favoritesStore = FavoritesStore.shared

    private var currentEntry: Entry {
        fullEntry ?? entry
    }
    
    private var cleanedTranslation: String {
        (currentEntry.ru ?? "Без перевода")
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
                    Text(currentEntry.hanzi ?? "—")
                        .font(.system(size: 42, weight: .bold))

                    if let pinyin = currentEntry.pinyin, !pinyin.isEmpty {
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

                if let hanzi = currentEntry.hanzi, !hanzi.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Порядок черт")
                            .font(.headline)
                        StrokeOrderWebView(hanzi: hanzi)
                            .frame(height: 240)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
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
    }
    private func loadFullEntry() async {
        isLoading = true

        do {
            fullEntry = try await APIService.shared.fetchEntry(id: entry.id)
        } catch {
            // Keep showing search result data if full entry loading fails.
        }

        isLoading = false
    }
}
