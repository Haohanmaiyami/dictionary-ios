//
//  FavoritesView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import SwiftUI
import UIKit

struct FavoritesView: View {
    @ObservedObject private var store = FavoritesStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InkScreenHeader(label: "收藏")
                    InkLargeTitle(text: "Избранное")
                        .padding(.top, 2)

                    if store.items.isEmpty {
                        InkEmptyState(
                            image: "InkEmptyStar",
                            title: "Избранных слов пока нет",
                            message: "Нажмите ☆ в карточке слова, и оно появится здесь"
                        )
                    } else {
                        InkSubtitle(text: InkText.words(store.items.count))
                            .padding(.top, 4)

                        LazyVStack(spacing: 0) {
                            ForEach(store.items) { saved in
                                let entry = saved.toEntry()
                                NavigationLink(destination: EntryDetailView(entry: entry)) {
                                    InkEntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .background(Ink.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle("Избранное")
        }
    }

}
