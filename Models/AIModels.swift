//
//  AIModels.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/18/26.
//

import Foundation

struct AIDictionaryHit: Codable, Identifiable {
    let id = UUID()
    let hanzi: String?
    let pinyin: String?
    let ru: String?
    let pos: String?
    enum CodingKeys: String, CodingKey {
        case hanzi, pinyin, ru, pos
    }
}


struct AIAnalyzeRequest: Codable {
    let text: String
}

struct AIAnalyzeResponse: Codable {
    let text: String
    let dictionaryHits: [AIDictionaryHit]
    let analysis: String
    
    enum CodingKeys: String, CodingKey {
        case text
        case dictionaryHits = "dictionary_hits"
        case analysis
    }
}

struct AITranslateRuToCnRequest: Codable {
    let text: String
}

struct AITranslateRuToCnResponse: Codable {
    let text: String
    let translation: String
}

struct AITranslateResponse: Codable {
    let text: String
    let translation: String
    let dictionaryHits: [AIDictionaryHit]?
    
    enum CodingKeys: String, CodingKey {
        case text
        case translation
        case dictionaryHits = "dictionary_hits"
    }
}




