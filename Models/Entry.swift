//
//  Entry.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import Foundation

struct Entry: Codable, Identifiable {
    let id: Int
    let hanzi: String?
    let pinyin: String?
    let ru: String?
    let pos: String?
    let examples: String?
}
