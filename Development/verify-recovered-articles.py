#!/usr/bin/env python3
"""Offline check of recovered v2 API articles using actual Swift models/renderer.

Expected values come independently from raw JSON: tolerant decoding cannot
silently turn a recovered article back into a legacy fallback.
"""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / ".verification"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--fixtures", type=Path, required=True,
                    help="JSON array of complete API entries, all with recovered v2 articles")
args = parser.parse_args()
fixtures = args.fixtures.resolve(strict=True)
ARTIFACTS.mkdir(exist_ok=True)

source = "\n".join((ROOT / name).read_text() for name in [
    "Models/Entry.swift", "Models/SavedEntry.swift",
])
renderer = (ROOT / "Views/EntryDetailView.swift").read_text().split(
    "// BEGIN OFFLINE ARTICLE RENDERER\n", 1
)[1].split("// END OFFLINE ARTICLE RENDERER", 1)[0]
source += "\nimport SwiftUI\n" + renderer
source += r'''

struct CorpusFailure: Error, CustomStringConvertible { let description: String }

@main
struct RecoveredArticleChecks {
    static func require(_ condition: @autoclosure () -> Bool, _ context: String) throws {
        guard condition() else { throw CorpusFailure(description: context) }
    }

    static func exact(_ actual: String, _ expected: String) -> Bool {
        actual.utf8.elementsEqual(expected.utf8)
    }

    static func nullableString(_ raw: Any?, _ context: String) throws -> String? {
        if raw == nil || raw is NSNull { return nil }
        guard let value = raw as? String else {
            throw CorpusFailure(description: context + ": expected string or null")
        }
        return value
    }

    static func sameOptional(_ actual: String?, _ expected: String?) -> Bool {
        switch (actual, expected) {
        case let (.some(a), .some(b)): return exact(a, b)
        case (.none, .none): return true
        default: return false
        }
    }

    static func checkEntryFields(_ entry: Entry, raw: [String: Any], context: String) throws {
        guard let expectedID = raw["id"] as? Int else {
            throw CorpusFailure(description: context + ": missing ID")
        }
        try require(entry.id == expectedID, context + ": ID changed")
        for (key, value) in [
            ("hanzi", entry.hanzi), ("pinyin", entry.pinyin), ("ru", entry.ru),
            ("pos", entry.pos), ("examples", entry.examples),
        ] {
            let expected = try nullableString(raw[key], context + ": " + key)
            try require(sameOptional(value, expected), context + ": legacy field changed: " + key)
        }
    }

    static func verify() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        guard let expectedEntries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !expectedEntries.isEmpty else {
            throw CorpusFailure(description: "Fixtures must be a nonempty JSON entry array")
        }
        let decoder = JSONDecoder()
        let entries = try decoder.decode([Entry].self, from: data)
        try require(entries.count == expectedEntries.count, "Entry count changed")
        var ids = Set<Int>()
        var structuredCount = 0
        var styledCount = 0
        var totalRows = 0
        var totalRuns = 0
        var totalReferences = 0
        var maxRows = 0
        var maxRunsPerRow = 0
        var maxRunsPerArticle = 0
        var maxReferencesPerRow = 0
        var maxReferencesPerArticle = 0
        var maxLevel = 0

        for (entryIndex, pair) in zip(entries, expectedEntries).enumerated() {
            let (entry, raw) = pair
            let context = "entry[\(entryIndex)] id=\(entry.id)"
            try require(ids.insert(entry.id).inserted, context + ": duplicate fixture ID")
            try checkEntryFields(entry, raw: raw, context: context)
            guard let expectedArticle = raw["article"] as? [String: Any],
                  expectedArticle["version"] as? Int == 2,
                  let expectedBlocks = expectedArticle["blocks"] as? [[String: Any]],
                  !expectedBlocks.isEmpty else {
                throw CorpusFailure(description: context + ": expected nonempty v2 source article")
            }
            guard let article = entry.article else {
                throw CorpusFailure(description: context + ": recovered article was discarded by Swift decoder")
            }
            structuredCount += 1
            try require(article.version == 2, context + ": article version changed")
            let rows = article.rows
            try require(rows.count == expectedBlocks.count && article.blocks.count == expectedBlocks.count,
                        context + ": block count changed")
            totalRows += rows.count
            maxRows = max(maxRows, rows.count)

            var expectedFormatting: [[[String: Any]]]? = nil
            if let rawFormatting = expectedArticle["formatting"], !(rawFormatting is NSNull) {
                guard let envelope = rawFormatting as? [String: Any],
                      envelope["version"] as? Int == 1,
                      let formattingRows = envelope["rows"] as? [[[String: Any]]] else {
                    throw CorpusFailure(description: context + ": invalid source formatting envelope")
                }
                try require(formattingRows.count == expectedBlocks.count,
                            context + ": source formatting row count mismatch")
                try require(article.formatting != nil, context + ": source formatting was discarded")
                expectedFormatting = formattingRows
                styledCount += 1
            } else {
                try require(article.formatting == nil, context + ": unexpected invented formatting")
            }

            var articleRuns = 0
            var articleReferences = 0
            for index in expectedBlocks.indices {
                let block = expectedBlocks[index]
                let row = rows[index]
                let decodedBlock = article.blocks[index]
                let rowContext = context + " block[\(index)]"
                guard let text = block["text"] as? String,
                      let level = block["level"] as? Int,
                      let kind = block["kind"] as? String,
                      let references = block["references"] as? [[String: Any]] else {
                    throw CorpusFailure(description: rowContext + ": incomplete source block")
                }
                let number = try nullableString(block["number"], rowContext + ": number")
                try require(exact(row.text, text) && exact(decodedBlock.text, text), rowContext + ": text changed")
                try require(row.level == level && decodedBlock.level == level, rowContext + ": source level changed")
                try require(row.kind.rawValue == kind && decodedBlock.kind.rawValue == kind,
                            rowContext + ": paragraph kind changed")
                try require(sameOptional(row.number, number) && sameOptional(decodedBlock.number, number),
                            rowContext + ": number changed")
                maxLevel = max(maxLevel, level)
                for (key, value) in [("chinese", decodedBlock.chinese), ("translation", decodedBlock.translation)] {
                    let expected = try nullableString(block[key], rowContext + ": " + key)
                    try require(sameOptional(value, expected), rowContext + ": supplemental example pair changed")
                }
                try require(row.references.count == references.count && decodedBlock.references == row.references,
                            rowContext + ": reference count/order changed")
                for (reference, expected) in zip(row.references, references) {
                    guard let target = expected["target"] as? String,
                          let label = expected["label"] as? String else {
                        throw CorpusFailure(description: rowContext + ": malformed source reference")
                    }
                    try require(exact(reference.target, target) && exact(reference.label, label),
                                rowContext + ": reference target/label changed")
                }
                totalReferences += references.count
                articleReferences += references.count
                maxReferencesPerRow = max(maxReferencesPerRow, references.count)

                if let expectedFormatting {
                    let expectedRuns = expectedFormatting[index]
                    guard let runs = row.runs, runs.count == expectedRuns.count else {
                        throw CorpusFailure(description: rowContext + ": formatting runs lost")
                    }
                    var expectedRunText = ""
                    for (run, expectedRun) in zip(runs, expectedRuns) {
                        guard let runText = expectedRun["text"] as? String else {
                            throw CorpusFailure(description: rowContext + ": source run text missing")
                        }
                        try require(exact(run.text, runText), rowContext + ": run text changed")
                        expectedRunText += runText
                        for (key, actual) in [("italic", run.italic), ("bold", run.bold), ("underline", run.underline)] {
                            let expected = expectedRun[key] as? Bool ?? false
                            try require(actual == expected, rowContext + ": run style changed: " + key)
                        }
                        let expectedColor = try nullableString(expectedRun["color"], rowContext + ": run color")
                        try require(sameOptional(run.color?.rawValue, expectedColor), rowContext + ": run color changed")
                    }
                    try require(exact(expectedRunText, text), rowContext + ": source formatting text is inconsistent")
                    totalRuns += runs.count
                    articleRuns += runs.count
                    maxRunsPerRow = max(maxRunsPerRow, runs.count)
                } else {
                    try require(row.runs == nil, rowContext + ": unexpected runs")
                }

                // Numbering in the contract is digit-only, without punctuation.
                // Use raw JSON rather than row.displayText as the renderer oracle.
                let expectedDisplay = (number == nil ? "" : number! + ") ") + text
                try require(exact(row.displayText, expectedDisplay), rowContext + ": displayed numbering changed")
                for scheme in [ColorScheme.light, .dark] {
                    let rendered = DictionaryArticleRenderer.paragraph(row: row, colorScheme: scheme)
                    try require(exact(String(rendered.characters), expectedDisplay),
                                rowContext + ": attributed renderer changed source content")
                }
            }
            maxRunsPerArticle = max(maxRunsPerArticle, articleRuns)
            maxReferencesPerArticle = max(maxReferencesPerArticle, articleReferences)
            let saved = SavedEntry(from: entry)
            let restored = try decoder.decode(SavedEntry.self, from: JSONEncoder().encode(saved))
            try require(restored == saved && restored.toEntry().article == article,
                        context + ": saved-entry round trip changed article")
            try checkEntryFields(restored.toEntry(), raw: raw, context: context + " restored")
        }
        try require(structuredCount == expectedEntries.count, "Some recovered articles were silently lost")
        let savedArray = entries.map(SavedEntry.init(from:))
        let restoredArray = try decoder.decode([SavedEntry].self, from: JSONEncoder().encode(savedArray))
        try require(savedArray == restoredArray, "Whole favorites/history array failed round trip")
        print("PASS: \(structuredCount)/\(expectedEntries.count) recovered v2 articles retained; \(styledCount) with formatting")
        print("PASS: raw JSON fields, paragraph order/text/levels/numbers, examples, references and styles match Swift; saved array round-trips")
        print("PASS: every paragraph renders unchanged in light and dark palettes")
        print("COUNTS: rows=\(totalRows), runs=\(totalRuns), references=\(totalReferences); MAX: rows/article=\(maxRows), runs/row=\(maxRunsPerRow), runs/article=\(maxRunsPerArticle), references/row=\(maxReferencesPerRow), references/article=\(maxReferencesPerArticle), level=\(maxLevel)")
        print("No app launch or network request was performed.")
    }

    static func main() {
        do { try verify() }
        catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
'''
source_path = ARTIFACTS / "RecoveredArticleChecks.swift"
source_path.write_text(source)
binary = ARTIFACTS / "recovered-article-checks"
env = dict(os.environ)
env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
compiled = subprocess.run([
    "/usr/bin/xcrun", "swiftc", "-parse-as-library",
    "-module-cache-path", str(ARTIFACTS / "swift-module-cache"),
    str(source_path), "-o", str(binary),
], env=env, capture_output=True, text=True)
compile_log = ARTIFACTS / "recovered-article-checks-compile.log"
compile_log.write_text(compiled.stdout + compiled.stderr)
if compiled.returncode:
    raise SystemExit(f"Swift compile failed; inspect {compile_log}")
raise SystemExit(subprocess.run([str(binary), str(fixtures)], env=env).returncode)
