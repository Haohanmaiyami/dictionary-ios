//
//  HistoryStore.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import SwiftUI
import Foundation
import Combine


final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var items: [SavedEntry] = []

    private let key = "history_entries"
    private let maxItems = 50

    private init() {
        load()
    }

    func add(_ entry: Entry) {
        let saved = SavedEntry(from: entry)

        items.removeAll { $0.id == entry.id }
        items.insert(saved, at: 0)

        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    func clear() {
        items = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        items = (try? JSONDecoder().decode([SavedEntry].self, from: data)) ?? []
    }

    private func save() {
        let data = try? JSONEncoder().encode(items)
        UserDefaults.standard.set(data, forKey: key)
    }
}
