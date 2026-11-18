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
    let article: DictionaryArticle?

    init(from entry: Entry) {
        self.id = entry.id
        self.hanzi = entry.hanzi
        self.pinyin = entry.pinyin
        self.ru = entry.ru
        self.pos = entry.pos
        self.examples = entry.examples
        self.article = entry.article
    }

    init(from decoder: Decoder) throws {
        // Reuse Entry's tolerant optional-article decoder for existing favorites/history.
        self.init(from: try Entry(from: decoder))
    }

    func toEntry() -> Entry {
        Entry(
            id: id,
            hanzi: hanzi,
            pinyin: pinyin,
            ru: ru,
            pos: pos,
            examples: examples,
            article: article
        )
    }
}
