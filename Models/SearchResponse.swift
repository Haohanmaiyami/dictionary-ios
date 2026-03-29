//
//  SearchResponse.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import Foundation

struct SearchResponse: Codable {
    let q: String
    let count: Int
    let results: [Entry]
}
