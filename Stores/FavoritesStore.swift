//
//  FavoritesStore.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import SwiftUI
import Foundation
import Combine


final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var items: [SavedEntry] = []

    private let key = "favorite_entries"

    private init() {
        load()
    }

    func contains(_ entry: Entry) -> Bool {
        items.contains { $0.id == entry.id }
    }

    func toggle(_ entry: Entry) {
        let saved = SavedEntry(from: entry)

        if let index = items.firstIndex(where: { $0.id == entry.id }) {
            items.remove(at: index)
        } else {
            items.insert(saved, at: 0)
        }

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
