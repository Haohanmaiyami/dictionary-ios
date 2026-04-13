//
//  EntryDetailView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//


import SwiftUI

struct EntryDetailView: View {
    let entry: Entry
    
    private var cleanedTranslation: String {
        (entry.ru ?? "Без перевода")
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var cleanedExamples: String {
        (entry.examples ?? "Примеры отсутствуют")
            .replacingOccurrences(of: "<br>", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                VStack(spacing: 8) {
                    Text(entry.hanzi ?? "—")
                        .font(.system(size: 42, weight: .bold))

                    if let pinyin = entry.pinyin, !pinyin.isEmpty {
                        Text(pinyin)
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

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

                if let hanzi = entry.hanzi, !hanzi.isEmpty {
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
    }
}
