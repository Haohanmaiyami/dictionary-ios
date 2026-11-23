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
    let article: DictionaryArticle?
    let headword: String?
    let headwordLanguage: String?

    // Source metadata is explicit; Cyrillic in a Chinese translation is not provenance.
    var isRussianHeadword: Bool {
        headwordLanguage == "ru" &&
        !(headword?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var displayHeadword: String {
        if isRussianHeadword, let headword {
            return headword.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return hanzi ?? "—"
    }

    var displayPinyin: String? { isRussianHeadword ? nil : pinyin }

    var previewText: String {
        let text: String
        if isRussianHeadword {
            // BRuKS stores its full Chinese article separately from the first hanzi.
            text = article?.rows.map(\.displayText).joined(separator: "\n") ?? examples ?? "Без перевода"
        } else {
            text = ru ?? "Без перевода"
        }
        return text.replacingOccurrences(of: "<br>", with: isRussianHeadword ? "\n" : " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(id: Int, hanzi: String?, pinyin: String?, ru: String?, pos: String?,
         examples: String?, article: DictionaryArticle? = nil,
         headword: String? = nil, headwordLanguage: String? = nil) {
        self.id = id
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.ru = ru
        self.pos = pos
        self.examples = examples
        self.article = article
        self.headword = headword
        self.headwordLanguage = headwordLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case id, hanzi, pinyin, ru, pos, examples, article, headword
        case headwordLanguage = "headword_language"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        hanzi = try values.decodeIfPresent(String.self, forKey: .hanzi)
        pinyin = try values.decodeIfPresent(String.self, forKey: .pinyin)
        ru = try values.decodeIfPresent(String.self, forKey: .ru)
        pos = try values.decodeIfPresent(String.self, forKey: .pos)
        examples = try values.decodeIfPresent(String.self, forKey: .examples)
        // New metadata must never make a previously saved entry unreadable.
        // Unknown versions or malformed articles use the legacy strings instead.
        article = try? values.decodeIfPresent(DictionaryArticle.self, forKey: .article)
        headword = try? values.decodeIfPresent(String.self, forKey: .headword)
        headwordLanguage = try? values.decodeIfPresent(String.self, forKey: .headwordLanguage)
    }
}

struct DictionaryArticle: Codable, Equatable {
    let version: Int
    let senses: [DictionarySense]
    let blocks: [DictionaryArticleBlock]
    private(set) var formatting: DictionaryArticleFormatting?

    private enum CodingKeys: String, CodingKey { case version, senses, blocks, formatting }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        switch version {
        case 1:
            senses = try values.decode([DictionarySense].self, forKey: .senses)
            blocks = []
            let otherBlocks = try values.decodeIfPresent([DictionaryArticleBlock].self, forKey: .blocks)
            guard otherBlocks?.isEmpty != false,
                  !senses.isEmpty, senses.allSatisfy({ $0.isUsable }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .senses, in: values,
                    debugDescription: "Incomplete dictionary senses"
                )
            }
        case 2:
            senses = []
            blocks = try values.decode([DictionaryArticleBlock].self, forKey: .blocks)
            let otherSenses = try values.decodeIfPresent([DictionarySense].self, forKey: .senses)
            guard otherSenses?.isEmpty != false,
                  !blocks.isEmpty, blocks.allSatisfy({ $0.isUsable }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .blocks, in: values,
                    debugDescription: "Incomplete dictionary paragraphs"
                )
            }
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: values,
                debugDescription: "Unsupported dictionary article version"
            )
        }
        // Styling is supplemental: a malformed or future envelope must never
        // discard valid definitions, examples, references, or saved entries.
        formatting = nil
        if let candidate = try? values.decodeIfPresent(DictionaryArticleFormatting.self, forKey: .formatting),
           candidate.matches(rows: unformattedRows) {
            formatting = candidate
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        if version == 1 {
            try values.encode(senses, forKey: .senses)
        } else {
            try values.encode(blocks, forKey: .blocks)
        }
        try values.encodeIfPresent(formatting, forKey: .formatting)
    }

    /// One ordered row per paragraph. Version 2 keeps source levels and never
    /// guesses which definition owns an unnumbered continuation or example.
    var rows: [DictionaryArticleRow] {
        var result = unformattedRows
        if let formatting {
            for index in result.indices {
                result[index].runs = formatting.rows[index]
            }
        }
        return result
    }

    private var unformattedRows: [DictionaryArticleRow] {
        if version == 2 {
            return blocks.map {
                DictionaryArticleRow(
                    level: $0.level, kind: $0.kind, number: $0.number,
                    text: $0.text, references: $0.references,
                    isEmphasized: $0.level == 1 && $0.kind == .definition
                )
            }
        }
        return senses.flatMap { sense in
            var result: [DictionaryArticleRow] = []
            if !sense.definition.isEmpty || sense.number != nil || !sense.references.isEmpty {
                result.append(DictionaryArticleRow(
                    level: 1, kind: .definition, number: sense.number,
                    text: sense.definition, references: sense.references, isEmphasized: false
                ))
            }
            result += sense.examples.map { example in
                DictionaryArticleRow(
                    level: 2, kind: .example, number: nil,
                    text: example.chinese + (example.translation.isEmpty ? "" : " — " + example.translation),
                    references: [], isEmphasized: false
                )
            }
            return result
        }
    }
}

enum DictionaryParagraphKind: String, Codable {
    case definition, example
}

struct DictionaryArticleBlock: Codable, Equatable {
    let level: Int
    let kind: DictionaryParagraphKind
    let number: String?
    let text: String
    let references: [DictionaryReference]
    let chinese: String?
    let translation: String?

    fileprivate var isUsable: Bool {
        guard (1...4).contains(level),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              references.allSatisfy({
                  !$0.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }) else {
            return false
        }
        switch kind {
        case .definition:
            guard chinese == nil && translation == nil else { return false }
            return number.map { !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } } ?? true
        case .example:
            guard number == nil else { return false }
            // Optional pairs are supplemental. The view always uses the full
            // authoritative text, including examples that cannot safely split.
            if let chinese, let translation {
                return !chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return chinese == nil && translation == nil
        }
    }
}

/// Shared by the view and the offline harness, so ordering and indentation are
/// checked without starting the app or contacting a server.
struct DictionaryArticleRow: Equatable {
    let level: Int
    let kind: DictionaryParagraphKind
    let number: String?
    let text: String
    let references: [DictionaryReference]
    let isEmphasized: Bool
    var runs: [DictionaryInlineRun]? = nil

    var indentation: Int { (level - 1) * 12 }
    var numberPrefix: String {
        number.map { $0.hasSuffix(")") ? "\($0) " : "\($0)) " } ?? ""
    }
    var displayText: String { numberPrefix + text }
}

/// Only these semantic colors are accepted. Arbitrary DSL colors, HTML, CSS,
/// and unknown future formatting fall back to the authoritative plain rows.
enum DictionaryInlineColor: String, Codable {
    case green, blue, red, gray, primary, brown, violet, crimson
}

struct DictionaryInlineRun: Codable, Equatable {
    let text: String
    let italic: Bool
    let bold: Bool
    let underline: Bool
    let color: DictionaryInlineColor?

    private enum CodingKeys: String, CodingKey { case text, italic, bold, underline, color }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        text = try values.decode(String.self, forKey: .text)
        italic = try values.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        bold = try values.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        underline = try values.decodeIfPresent(Bool.self, forKey: .underline) ?? false
        color = try values.decodeIfPresent(DictionaryInlineColor.self, forKey: .color)
    }
}

struct DictionaryArticleFormatting: Codable, Equatable {
    let version: Int
    let rows: [[DictionaryInlineRun]]

    fileprivate func matches(rows articleRows: [DictionaryArticleRow]) -> Bool {
        version == 1 && rows.count == articleRows.count &&
        zip(rows, articleRows).allSatisfy { runs, row in
            // UTF-8 equality deliberately avoids accepting canonically
            // equivalent but changed source text or normalization offsets.
            runs.map(\.text).joined().utf8.elementsEqual(row.text.utf8)
        }
    }
}

struct DictionarySense: Codable, Equatable {
    let number: String?
    let definition: String
    let examples: [DictionaryExample]
    let references: [DictionaryReference]

    fileprivate var isUsable: Bool {
        (!definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         !examples.isEmpty || !references.isEmpty) &&
        examples.allSatisfy { !$0.chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        references.allSatisfy { !$0.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct DictionaryExample: Codable, Equatable {
    let chinese: String
    let translation: String
}

struct DictionaryReference: Codable, Equatable {
    let target: String
    let label: String
}

enum DictionaryReferenceError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let target):
            return "Статья «\(target)» пока не найдена в словаре."
        }
    }
}

enum DictionaryReferenceResolver {
    /// Search may return prefixes and similar words; only an exact headword is a link target.
    static func resolve(
        target: String,
        search: (String) async throws -> [Entry]
    ) async throws -> Entry {
        let query = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw DictionaryReferenceError.notFound(target) }
        let entries = try await search(query)
        guard let exact = entries.first(where: { $0.displayHeadword == query }) else {
            throw DictionaryReferenceError.notFound(query)
        }
        return exact
    }
}
