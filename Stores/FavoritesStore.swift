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
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

    /// Refresh an existing bookmark after fetching a complete article, without
    /// adding a favorite or changing its position in the user's list.
    func refreshIfSaved(_ entry: Entry) {
        guard let index = items.firstIndex(where: { $0.id == entry.id }) else { return }
        let saved = SavedEntry(from: entry)
        guard items[index] != saved else { return }
        items[index] = saved
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        items = (try? JSONDecoder().decode([SavedEntry].self, from: data)) ?? []
    }

    private func save() {
        let data = try? JSONEncoder().encode(items)
        defaults.set(data, forKey: key)
    }
}
