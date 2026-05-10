//
//  FavoritesView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import SwiftUI

struct FavoritesView: View {
    @ObservedObject private var store = FavoritesStore.shared

    var body: some View {
        NavigationStack {
            List {
                if store.items.isEmpty {
                    Text("Избранных слов пока нет")
                        .foregroundColor(.gray)
                } else {
                    ForEach(store.items) { saved in
                        NavigationLink(destination: EntryDetailView(entry: saved.toEntry())) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(saved.hanzi ?? "—")
                                    .font(.headline)

                                if let pinyin = saved.pinyin, !pinyin.isEmpty {
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
            .navigationTitle("Избранное")
        }
    }
}
