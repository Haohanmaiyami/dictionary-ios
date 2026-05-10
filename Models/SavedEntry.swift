//
//  SavedEntry.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 5/9/26.
//

import Foundation

struct SavedEntry: Identifiable, Codable, Equatable {
    let id: Int
    let hanzi: String?
    let pinyin: String?
    let ru: String?
    let pos: String?
    let examples: String?

    init(from entry: Entry) {
        self.id = entry.id
        self.hanzi = entry.hanzi
        self.pinyin = entry.pinyin
        self.ru = entry.ru
        self.pos = entry.pos
        self.examples = entry.examples
    }

    func toEntry() -> Entry {
        Entry(
            id: id,
            hanzi: hanzi,
            pinyin: pinyin,
            ru: ru,
            pos: pos,
            examples: examples
        )
    }
}
