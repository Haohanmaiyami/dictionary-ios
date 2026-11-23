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
                        let entry = saved.toEntry()
                        NavigationLink(destination: EntryDetailView(entry: entry)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.displayHeadword)
                                    .font(.headline)

                                if let pinyin = entry.displayPinyin, !pinyin.isEmpty {
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
            .navigationTitle("Избранное")
        }
    }
}
