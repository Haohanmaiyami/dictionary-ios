//
//  HistoryView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared

    var body: some View {

        NavigationStack {

            List {

                if store.items.isEmpty {

                    Text("История пока пустая")
                        .foregroundColor(.gray)

                } else {

                    ForEach(store.items) { saved in

                        NavigationLink(
                            destination: EntryDetailView(entry: saved.toEntry())
                        ) {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(saved.hanzi ?? "—")
                                    .font(.headline)

                                if let pinyin = saved.pinyin,
                                   !pinyin.isEmpty {

                                    Text(pinyin)
                                        .foregroundColor(.gray)
                                }

                                Text(saved.ru ?? "Без перевода")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
            }
            .navigationTitle("История")

            .toolbar {

                Button("Очистить") {
                    store.clear()
                }
            }
        }
    }
}
