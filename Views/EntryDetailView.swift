//
//  EntryDetailView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//


import SwiftUI

struct EntryDetailView: View {
    let entry: Entry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Перевод")
                        .font(.headline)

                    Text(entry.ru ?? "Без перевода")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Примеры")
                        .font(.headline)

                    Text(entry.examples ?? "Примеры отсутствуют")
                        .font(.body)
                }

                if let hanzi = entry.hanzi, !hanzi.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Порядок черт")
                            .font(.headline)
                        StrokeOrderWebView(hanzi: hanzi)
                            .frame(height: 240)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Слово")
        .navigationBarTitleDisplayMode(.inline)
    }
}
