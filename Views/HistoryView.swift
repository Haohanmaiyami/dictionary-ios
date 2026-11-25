//
//  HistoryView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import SwiftUI
import UIKit

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared

    var body: some View {

        NavigationStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    InkScreenHeader(label: "历史") {
                        Button("Очистить") {
                            store.clear()
                        }
                        .font(InkFont.serif(16, .semibold))
                        .foregroundStyle(store.items.isEmpty ? Ink.mutedSoft : Ink.cinnabar)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(store.items.isEmpty)
                    }
                    InkLargeTitle(text: "История")
                        .padding(.top, 2)

                    if store.items.isEmpty {
                        InkEmptyState(
                            image: "InkEmptyInk",
                            title: "История пока пустая",
                            message: "Здесь появятся слова, которые вы открывали"
                        )
                    } else {
                        InkSubtitle(text: "Последние 50 открытых слов")
                            .padding(.top, 4)

                        LazyVStack(spacing: 0) {
                            ForEach(store.items) { saved in
                                let entry = saved.toEntry()

                                NavigationLink(
                                    destination: EntryDetailView(entry: entry)
                                ) {
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
            .navigationTitle("История")
        }
    }

}
