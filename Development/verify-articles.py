#!/usr/bin/env python3
"""Compile and run the real Swift models/reference resolver without any network I/O."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / '.verification'
ARTIFACTS.mkdir(exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument('--fixtures', type=Path, help='Optional JSON array of local API entries')
parser.add_argument('--hierarchy-fixtures', type=Path, help='Optional JSON array of API entries containing version 2 articles')
parser.add_argument('--formatting-fixtures', type=Path, help='Optional JSON array of API entries with inline formatting')
args = parser.parse_args()

source = '\n'.join((ROOT / name).read_text() for name in [
    'Models/Entry.swift', 'Models/SavedEntry.swift',
])
renderer = (ROOT / 'Views/EntryDetailView.swift').read_text().split(
    '// BEGIN OFFLINE ARTICLE RENDERER\n', 1
)[1].split('// END OFFLINE ARTICLE RENDERER', 1)[0]
source += '\nimport SwiftUI\n' + renderer
source += r'''

@main
struct ArticleChecks {
    static func entry(_ id: Int, _ hanzi: String) -> Entry {
        Entry(id: id, hanzi: hanzi, pinyin: nil, ru: "legacy", pos: nil, examples: nil)
    }

    static func main() async throws {
        let decoder = JSONDecoder()
        let legacy = #"{"id":42,"hanzi":"你好","ru":"привет","examples":"пример"}"#
        let old = try decoder.decode(Entry.self, from: Data(legacy.utf8))
        precondition(old.id == 42 && old.article == nil && old.ru == "привет")
        let savedOld = try decoder.decode(SavedEntry.self, from: Data(legacy.utf8))
        precondition(savedOld.toEntry().id == 42 && savedOld.article == nil)
        print("PASS: old API responses and saved entries decode without the new field")

        let article = #"{"version":1,"senses":[{"number":"1","definition":"привет","examples":[{"chinese":"王女士，你好！","translation":"Добрый день, госпожа Ван!"}],"references":[]},{"number":"2","definition":"см. 妈屄","examples":[],"references":[{"target":"妈屄","label":"妈屄"}]}]}"#
        let newJSON = "{\"id\":43,\"hanzi\":\"你好\",\"ru\":\"fallback\",\"article\":" + article + "}"
        let new = try decoder.decode(Entry.self, from: Data(newJSON.utf8))
        precondition(new.article?.senses.count == 2)
        precondition(new.article?.senses[0].examples[0].translation == "Добрый день, госпожа Ван!")
        let saved = SavedEntry(from: new)
        let roundTrip = try decoder.decode(SavedEntry.self, from: JSONEncoder().encode(saved))
        precondition(roundTrip == saved && roundTrip.toEntry().article == new.article)
        precondition(roundTrip.id == 43 && roundTrip.toEntry().ru == "fallback")
        print("PASS: saving and restoring retains IDs, legacy text, senses, example pairs, and references")

        let nestedArticle = #"{"version":2,"blocks":[{"level":1,"kind":"definition","number":null,"text":"I гл. А","references":[]},{"level":2,"kind":"definition","number":"1","text":"рассыпать; рассеивать","references":[]},{"level":3,"kind":"example","text":"散传单 распространять листовки","references":[],"chinese":"散传单","translation":"распространять листовки"},{"level":2,"kind":"definition","text":"мед. порошок","references":[]},{"level":3,"kind":"definition","number":"2","text":"частный случай","references":[]},{"level":4,"kind":"example","text":"A → 甲; пояснение с 乙 без надёжного разделения","references":[]},{"level":1,"kind":"definition","text":"II сущ.","references":[]},{"level":2,"kind":"definition","text":"см. 好","references":[{"target":"好","label":"好"}]},{"level":3,"kind":"example","text":"Пример; см. 好","references":[{"target":"好","label":"好"}]}]}"#
        let nestedJSON = "{\"id\":45,\"hanzi\":\"散\",\"ru\":\"legacy preserved\",\"article\":" + nestedArticle + "}"
        let nested = try decoder.decode(Entry.self, from: Data(nestedJSON.utf8))
        guard let hierarchy = nested.article else { preconditionFailure("Version 2 was discarded") }
        precondition(hierarchy.version == 2 && hierarchy.senses.isEmpty && hierarchy.blocks.count == 9)
        let rows = hierarchy.rows
        precondition(rows.map(\.level) == [1, 2, 3, 2, 3, 4, 1, 2, 3])
        precondition(rows.map(\.indentation) == [0, 12, 24, 12, 24, 36, 0, 12, 24])
        precondition(rows.map(\.text) == hierarchy.blocks.map(\.text))
        precondition(rows.map(\.isEmphasized) == [true, false, false, false, false, false, true, false, false])
        precondition(rows[0].displayText == "I гл. А")
        precondition(rows[1].displayText == "1) рассыпать; рассеивать")
        precondition(rows[2].displayText == "散传单 распространять листовки" && rows[2].kind == .example)
        precondition(rows[3].displayText == "мед. порошок")
        precondition(rows[5].displayText == "A → 甲; пояснение с 乙 без надёжного разделения")
        precondition(rows[7].references[0].target == "好" && rows[8].references[0].target == "好")
        let nestedSaved = SavedEntry(from: nested)
        let nestedRestored = try decoder.decode(SavedEntry.self, from: JSONEncoder().encode(nestedSaved))
        precondition(nestedRestored == nestedSaved && nestedRestored.toEntry().article == hierarchy)
        let encodedHierarchy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(hierarchy)) as! [String: Any]
        let encodedV1 = try JSONSerialization.jsonObject(with: JSONEncoder().encode(new.article!)) as! [String: Any]
        precondition(encodedHierarchy["senses"] == nil && encodedHierarchy["blocks"] != nil)
        precondition(encodedV1["blocks"] == nil && encodedV1["senses"] != nil)
        precondition(new.article!.rows.map(\.displayText) == ["1) привет", "王女士，你好！ — Добрый день, госпожа Ван!", "2) см. 妈屄"])
        let v2WithEmptySenses = nestedArticle.replacingOccurrences(of: "\"version\":2", with: "\"version\":2,\"senses\":[]")
        let v1WithEmptyBlocks = article.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"blocks\":[]")
        let decodedEmptySenses = try decoder.decode(DictionaryArticle.self, from: Data(v2WithEmptySenses.utf8))
        let decodedEmptyBlocks = try decoder.decode(DictionaryArticle.self, from: Data(v1WithEmptyBlocks.utf8))
        precondition(decodedEmptySenses == hierarchy && decodedEmptyBlocks == new.article!)
        print("PASS: version 2 preserves all paragraph order, four indentation levels, continuation text and references")
        print("PASS: version 1 rendering and saved data remain compatible; version 2 round-trips without invented senses")

        for optionalValue in [
            "null", "42", #""bad""#, #"{"version":2,"senses":[]}"#,
            #"{"version":1,"senses":[]}"#,
            #"{"version":1,"senses":[{"number":1,"definition":"bad","examples":[],"references":[]}]}"#,
            #"{"version":1,"senses":[{"definition":"bad","examples":[{"chinese":"x","translation":42}],"references":[]}]}"#,
            #"{"version":1,"senses":[{"definition":"bad","examples":[],"references":[{"target":"","label":"bad"}]}]}"#,
            article.replacingOccurrences(of: "\"version\":1", with: "\"version\":99"),
            #"{"version":2,"blocks":[]}"#,
            #"{"version":2,"blocks":[{"level":1,"kind":"definition","references":[]}]}"#,
            #"{"version":2,"blocks":[{"level":1,"kind":"definition","text":" ","references":[]}]}"#,
            nestedArticle.replacingOccurrences(of: "\"level\":4", with: "\"level\":5"),
            nestedArticle.replacingOccurrences(of: "\"level\":1", with: "\"level\":0"),
            nestedArticle.replacingOccurrences(of: "\"level\":4", with: "\"level\":3.5"),
            nestedArticle.replacingOccurrences(of: "\"kind\":\"definition\"", with: "\"kind\":\"other\""),
            nestedArticle.replacingOccurrences(of: "\"number\":\"1\"", with: "\"number\":\"1)\""),
            nestedArticle.replacingOccurrences(of: "\"number\":\"1\"", with: "\"number\":\"\""),
            nestedArticle.replacingOccurrences(of: "\"kind\":\"example\"", with: "\"kind\":\"example\",\"number\":\"3\""),
            nestedArticle.replacingOccurrences(of: "\"kind\":\"example\"", with: "\"kind\":\"definition\""),
            nestedArticle.replacingOccurrences(of: ",\"translation\":\"распространять листовки\"", with: ""),
            nestedArticle.replacingOccurrences(of: ",\"chinese\":\"散传单\"", with: ""),
            nestedArticle.replacingOccurrences(of: "\"chinese\":\"散传单\"", with: "\"chinese\":\" \""),
            nestedArticle.replacingOccurrences(of: "\"target\":\"好\"", with: "\"target\":\" \""),
            nestedArticle.replacingOccurrences(of: "\"version\":2", with: #""version":2,"senses":[{"definition":"must not disappear","examples":[],"references":[]}]"#),
            article.replacingOccurrences(of: "\"version\":1", with: #""version":1,"blocks":[{"level":1,"kind":"definition","text":"must not disappear","references":[]}]"#),
        ] {
            let malformed = "{\"id\":44,\"hanzi\":\"你\",\"ru\":\"ты\",\"article\":" + optionalValue + "}"
            // This matches the stores' whole-array decode: one bad article must not erase favorites/history.
            let listJSON = "[" + legacy + "," + newJSON + "," + malformed + "," + nestedJSON + "]"
            let list = try decoder.decode([SavedEntry].self, from: Data(listJSON.utf8))
            precondition(list.map(\.id) == [42, 43, 44, 45])
            precondition(list[2].article == nil && list[2].ru == "ты")
            precondition(list[1].article != nil)
            precondition(list[3].article == hierarchy)
        }
        print("PASS: malformed/unknown optional articles cannot discard the saved-entry array")

        func withFormatting(_ entryJSON: String, _ formatting: Any) throws -> Entry {
            var object = try JSONSerialization.jsonObject(with: Data(entryJSON.utf8)) as! [String: Any]
            var articleObject = object["article"] as! [String: Any]
            articleObject["formatting"] = formatting
            object["article"] = articleObject
            return try decoder.decode(Entry.self, from: JSONSerialization.data(withJSONObject: object))
        }
        let formatting: [String: Any] = ["version": 1, "rows": [
            [["text": "привет"]],
            [["text": "王女士，你好！", "bold": true], ["text": " — "],
             ["text": "Добрый день, госпожа Ван!", "italic": true]],
            [["text": "см.", "italic": true, "color": "green"], ["text": " "],
             ["text": "妈屄", "underline": true, "color": "blue"]],
        ]]
        let styled = try withFormatting(newJSON, formatting)
        guard let styledArticle = styled.article else { preconditionFailure("Styled article discarded") }
        precondition(styledArticle.formatting != nil)
        precondition(styledArticle.rows.map(\.displayText) == new.article!.rows.map(\.displayText))
        precondition(styledArticle.rows.map(\.references) == new.article!.rows.map(\.references))
        precondition(styledArticle.rows.map(\.indentation) == new.article!.rows.map(\.indentation))
        precondition(styledArticle.rows[0].runs?.first?.italic == false)
        precondition(styledArticle.rows[2].runs?.first?.italic == true)
        let styledSaved = SavedEntry(from: styled)
        let styledRestored = try decoder.decode(SavedEntry.self, from: JSONEncoder().encode(styledSaved))
        precondition(styledRestored == styledSaved && styledRestored.article == styledArticle)
        precondition(styledRestored.id == 43)

        for malformedFormatting: Any in [
            NSNull(), 42, "invalid", ["version": 99, "rows": formatting["rows"]!],
            ["version": 1, "rows": []], ["version": 1, "rows": [[[:]]]],
            ["version": 1, "rows": [["text": "привет"]]],
        ] {
            let rejected = try withFormatting(newJSON, malformedFormatting)
            precondition(rejected.article == new.article, "Bad formatting discarded or changed the plain article")
            let list = [SavedEntry(from: old), SavedEntry(from: rejected), styledSaved]
            let restored = try decoder.decode([SavedEntry].self, from: JSONEncoder().encode(list))
            precondition(restored.map(\.id) == [42, 43, 43] && restored[1].article == new.article)
        }
        for badRun: [String: Any] in [
            ["text": "привет", "italic": "true"], ["text": "привет", "bold": 1],
            ["text": "привет", "underline": []], ["text": "привет", "color": "chartreuse"],
            ["text": "привет", "color": 42], ["text": 42], ["text": "привет "],
        ] {
            var bad = formatting
            var rows = bad["rows"] as! [[[String: Any]]]
            rows[0] = [badRun]
            bad["rows"] = rows
            let rejected = try withFormatting(newJSON, bad)
            precondition(rejected.article == new.article)
        }
        print("PASS: optional formatting retains plain text, numbering, references, IDs and saved data; malformed/future metadata falls back independently")

        let styledParagraph = DictionaryArticleRenderer.paragraph(row: styledArticle.rows[2], colorScheme: .light)
        precondition(String(styledParagraph.characters) == "2) см. 妈屄")
        let labelRange = styledParagraph.range(of: "см.")!
        precondition(styledParagraph[labelRange].font == Font.body.weight(.regular).italic())
        precondition(styledParagraph[labelRange].foregroundColor == DictionaryArticleRenderer.color(.green, scheme: .light))
        let referenceRange = styledParagraph.range(of: "妈屄")!
        precondition(styledParagraph[referenceRange].underlineStyle == .single)
        precondition(styledParagraph[referenceRange].link?.scheme == "dictionary-reference")
        let prefixRange = styledParagraph.range(of: "2) ")!
        precondition(styledParagraph[prefixRange].font == nil && styledParagraph[prefixRange].foregroundColor == nil)
        let exampleParagraph = DictionaryArticleRenderer.paragraph(row: styledArticle.rows[1], colorScheme: .light)
        precondition(exampleParagraph[exampleParagraph.range(of: "王女士，你好！")!].font == Font.body.weight(.regular).bold())
        precondition(exampleParagraph[exampleParagraph.range(of: "Добрый день, госпожа Ван!")!].font == Font.body.weight(.regular).italic())
        precondition(exampleParagraph[exampleParagraph.range(of: " — ")!].foregroundColor == nil, "Uncolored example segment must inherit paragraph color")

        let unicodeText = "é 👩🏽‍💻 см. 妈屄; см. 妈屄"
        let unicodeObject: [String: Any] = ["id": 47, "hanzi": "测试", "ru": "legacy", "article": [
            "version": 2, "blocks": [["level": 1, "kind": "definition", "text": unicodeText,
                "references": [["target": "妈屄", "label": "妈屄"], ["target": "好", "label": "妈屄"]]]],
        ]]
        let unicodeJSON = String(data: try JSONSerialization.data(withJSONObject: unicodeObject), encoding: .utf8)!
        let unicodeFormatting: [String: Any] = ["version": 1, "rows": [[
            ["text": "é 👩🏽‍💻 см. ", "italic": true], ["text": "妈", "color": "green"],
            ["text": "屄; см. ", "bold": true], ["text": "妈屄", "color": "red"],
        ]]]
        let unicodeEntry = try withFormatting(unicodeJSON, unicodeFormatting)
        let unicodeRow = unicodeEntry.article!.rows[0]
        let unicodeParagraph = DictionaryArticleRenderer.paragraph(row: unicodeRow, colorScheme: .dark)
        precondition(String(unicodeParagraph.characters) == unicodeText)
        let referenceRanges = DictionaryArticleRenderer.referenceRanges(in: unicodeRow)
        precondition(referenceRanges.count == 2 && referenceRanges[0] != referenceRanges[1])
        for (index, span) in referenceRanges.enumerated() {
            let lower = AttributedString.Index(span!.lowerBound, within: unicodeParagraph)!
            let upper = AttributedString.Index(span!.upperBound, within: unicodeParagraph)!
            let link = unicodeParagraph[lower..<upper].link!
            let target = URLComponents(url: link, resolvingAgainstBaseURL: false)!.queryItems!.first!.value!
            precondition(target == (index == 0 ? "妈屄" : "好"))
            precondition(unicodeParagraph[lower..<upper].underlineStyle == .single)
        }
        precondition(unicodeParagraph[unicodeParagraph.range(of: "é 👩🏽‍💻 см. ")!].font == Font.body.weight(.semibold).italic())
        var normalizedFormatting = unicodeFormatting
        var normalizedRows = normalizedFormatting["rows"] as! [[[String: Any]]]
        normalizedRows[0][0]["text"] = "e\u{301} 👩🏽‍💻 см. "
        normalizedFormatting["rows"] = normalizedRows
        let normalized = try withFormatting(unicodeJSON, normalizedFormatting)
        precondition(normalized.article != nil && normalized.article?.formatting == nil, "Changed normalization must not be treated as exact source text")
        for color in [DictionaryInlineColor.green, .blue, .red, .gray, .brown, .violet, .crimson] {
            precondition(DictionaryArticleRenderer.color(color, scheme: .light) != DictionaryArticleRenderer.color(color, scheme: .dark))
        }
        precondition(DictionaryArticleRenderer.color(.primary, scheme: .light) == Color.primary)
        precondition(DictionaryArticleRenderer.color(.primary, scheme: .dark) == Color.primary)
        print("PASS: real attributed renderer preserves Unicode, repeated and split reference labels, italic/bold/underline, adaptive colors and unstyled number prefixes")

        let found = try await DictionaryReferenceResolver.resolve(target: " 妈屄 ") { query in
            precondition(query == "妈屄")
            return [entry(1, "妈屄的"), entry(2, "妈屄"), entry(3, "妈")]
        }
        precondition(found.id == 2)
        do {
            _ = try await DictionaryReferenceResolver.resolve(target: "妈屄") { _ in [entry(1, "妈屄的")] }
            preconditionFailure("An unrelated first result was accepted")
        } catch DictionaryReferenceError.notFound(let target) {
            precondition(target == "妈屄")
        }
        do {
            _ = try await DictionaryReferenceResolver.resolve(target: "  ") { _ in
                preconditionFailure("Empty reference performed a search")
            }
            preconditionFailure("Empty reference was accepted")
        } catch DictionaryReferenceError.notFound {}
        enum Offline: Error { case unavailable }
        do {
            _ = try await DictionaryReferenceResolver.resolve(target: "妈屄") { _ in throw Offline.unavailable }
            preconditionFailure("Search failure was swallowed")
        } catch Offline.unavailable {}
        print("PASS: reference resolution selects only an exact headword and reports missing/failed lookups")

        if let index = CommandLine.arguments.firstIndex(of: "--fixtures") {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            let entries = try decoder.decode([Entry].self, from: data)
            func required(_ word: String) -> DictionaryArticle {
                guard let article = entries.first(where: { $0.hanzi == word })?.article else {
                    preconditionFailure("Missing structured fixture: \(word)")
                }
                return article
            }
            let greeting = required("你好")
            precondition(!greeting.senses[0].definition.contains("Госпожа"))
            precondition(greeting.senses.flatMap(\.examples).contains(where: {
                $0.chinese.contains("王女士") && $0.translation.contains("Ван")
            }))
            let you = required("你")
            precondition(you.senses.flatMap(\.examples).count == 2)
            precondition(you.senses.flatMap(\.examples).contains(where: {
                $0.translation.contains("[вдвоём]") && !$0.translation.contains("\\")
            }))
            precondition(required("打扰").senses.count == 2)
            let what = required("什么")
            precondition(what.senses.count == 7)
            precondition(what.senses[3].number == "4")
            precondition(what.senses[3].examples.contains(where: {
                $0.chinese.contains("他们闹什么") && $0.translation.contains("шумят")
            }))
            precondition(required("妈逼").senses.flatMap(\.references).contains(where: { $0.target == "妈屄" }))
            let restored = try decoder.decode([SavedEntry].self, from: JSONEncoder().encode(entries.map(SavedEntry.init(from:))))
            precondition(restored.map(\.id) == entries.map(\.id))
            precondition(restored.map(\.article) == entries.map(\.article))
            print("PASS: five real backend fixtures decode with the requested structure and survive saving")
        }
        if let index = CommandLine.arguments.firstIndex(of: "--hierarchy-fixtures") {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            let entries = try decoder.decode([Entry].self, from: data)
            let sourceEntries = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
            precondition(!entries.isEmpty)
            var hierarchyCount = 0
            var simpleCount = 0
            for entry in entries {
                guard let article = entry.article else {
                    preconditionFailure("Structured hierarchy fixture was discarded: \(entry.id)")
                }
                if article.version == 2 {
                    hierarchyCount += 1
                    precondition(article.rows.map(\.text) == article.blocks.map(\.text))
                    precondition(article.rows.map(\.level) == article.blocks.map(\.level))
                    precondition(article.rows.map(\.references) == article.blocks.map(\.references))
                } else {
                    precondition(article.version == 1)
                    simpleCount += 1
                }
                let saved = SavedEntry(from: entry)
                let restored = try decoder.decode(SavedEntry.self, from: JSONEncoder().encode(saved))
                precondition(restored == saved && restored.toEntry().article == entry.article)
                precondition(restored.toEntry().ru == entry.ru && restored.toEntry().examples == entry.examples)
            }
            precondition(hierarchyCount == 12 && simpleCount == 6 && entries.count == 18)
            guard let recoveredNote = entries.first(where: { $0.hanzi == "一" })?.article,
                  recoveredNote.version == 2,
                  let noteText = recoveredNote.rows.last?.text,
                  let sourceNote = sourceEntries.first(where: { $0["hanzi"] as? String == "一" }),
                  let sourceArticle = sourceNote["article"] as? [String: Any],
                  let sourceBlocks = sourceArticle["blocks"] as? [[String: Any]],
                  let expectedNoteText = sourceBlocks.last?["text"] as? String else {
                preconditionFailure("Missing recovered 一 note")
            }
            precondition(noteText.contains("Примечание") &&
                         noteText.utf8.elementsEqual(expectedNoteText.utf8),
                         "Recovered 一 must retain the complete source note paragraph")
            print("PASS: \(hierarchyCount) version 2 backend fixtures preserve every paragraph, source level and reference through saving")
            print("PASS: all 18 hierarchy fixtures remain structured, including the complete recovered 一 note; 6 version 1 articles remain compatible")
        }
        if let index = CommandLine.arguments.firstIndex(of: "--formatting-fixtures") {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            let entries = try decoder.decode([Entry].self, from: data)
            var styledCount = 0
            for entry in entries {
                if let article = entry.article, let formatting = article.formatting {
                    styledCount += 1
                    precondition(formatting.rows.count == article.rows.count)
                    for row in article.rows {
                        for scheme in [ColorScheme.light, .dark] {
                            let rendered = DictionaryArticleRenderer.paragraph(row: row, colorScheme: scheme)
                            precondition(String(rendered.characters).utf8.elementsEqual(row.displayText.utf8))
                        }
                    }
                }
                let saved = SavedEntry(from: entry)
                let restored = try decoder.decode(SavedEntry.self, from: JSONEncoder().encode(saved))
                precondition(restored == saved && restored.toEntry().article == entry.article)
            }
            precondition(styledCount > 0, "No valid styling in supplied backend fixtures")
            print("PASS: \(styledCount) styled backend articles render without text changes in both themes and survive saved-entry round trips")
        }
        print("No app launch or network request was performed.")
    }
}
'''
source_path = ARTIFACTS / 'ArticleChecks.swift'
source_path.write_text(source)
binary = ARTIFACTS / 'article-checks'
r = subprocess.run([
    '/usr/bin/swiftc', '-parse-as-library',
    '-module-cache-path', str(ARTIFACTS / 'swift-module-cache'),
    str(source_path), '-o', str(binary),
], capture_output=True, text=True)
(ARTIFACTS / 'article-checks-compile.log').write_text(r.stdout + r.stderr)
if r.returncode:
    raise SystemExit('Swift compile failed; inspect .verification/article-checks-compile.log')
command = [str(binary)]
if args.fixtures:
    command += ['--fixtures', str(args.fixtures.resolve(strict=True))]
if args.hierarchy_fixtures:
    command += ['--hierarchy-fixtures', str(args.hierarchy_fixtures.resolve(strict=True))]
if args.formatting_fixtures:
    command += ['--formatting-fixtures', str(args.formatting_fixtures.resolve(strict=True))]
raise SystemExit(subprocess.run(command).returncode)
