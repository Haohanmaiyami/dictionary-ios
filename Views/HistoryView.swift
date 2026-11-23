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
                        let entry = saved.toEntry()

                        NavigationLink(
                            destination: EntryDetailView(entry: entry)
                        ) {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(entry.displayHeadword)
                                    .font(.headline)

                                if let pinyin = entry.displayPinyin,
                                   !pinyin.isEmpty {

                                    Text(pinyin)
                                        .foregroundColor(.gray)
                                }

                                Text(entry.previewText)
                                    .font(.subheadline)
                                    .lineLimit(entry.isRussianHeadword ? 3 : 1)
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
