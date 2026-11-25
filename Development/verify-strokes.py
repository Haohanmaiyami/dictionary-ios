#!/usr/bin/env python3
"""Check the actual production Han extractor and inline animation JavaScript offline.

The JavaScript harness stubs drawing; real WKWebView rendering is checked in Simulator.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / ".verification/strokes"
ARTIFACTS.mkdir(parents=True, exist_ok=True)
component = (ROOT / "Components/StrokeOrderWebView.swift").read_text()
content = component.split("enum StrokeOrderContent {", 1)[1].split("\nstruct StrokeOrderSection:", 1)[0]
source = "import Foundation\nimport JavaScriptCore\nenum StrokeOrderContent {" + content
source += r'''
@main
struct StrokeChecks {
    static func main() throws {
        let cases: [(String, [String])] = [
            ("你", ["你"]), ("你好", ["你", "好"]), ("人人", ["人", "人"]),
            ("王女士，你好！ 123 ABC🙂", ["王", "女", "士", "你", "好"]),
            ("", []), ("ABC 123!?🙂", []), ("𠮷〇神", ["𠮷", "〇", "神"]),
            ("禰\u{E0100}", ["禰"]),
        ]
        for (text, expected) in cases {
            precondition(StrokeOrderContent.characters(in: text) == expected, text)
        }
        precondition(StrokeOrderContent.characters(in: String(repeating: "你好", count: 100)).count == 200)
        for invalid in ["", "你好", "'", "</script>", "你<script>", "A", "🙂"] {
            precondition(StrokeOrderContent.html(for: invalid) == nil)
        }
        let assets = URL(fileURLWithPath: CommandLine.arguments[1])
        let html = StrokeOrderContent.html(for: "好", assetsURL: assets)!
        precondition(html.contains("connect-src 'none'") && html.contains("charDataLoader:function() { return data; }"))
        precondition(!html.contains("<script src=") && !html.contains("script.src ="))
        precondition(html.contains("HanziWriter") && html.contains("medians"))
        let missing = StrokeOrderContent.html(for: "𠀀", assetsURL: URL(fileURLWithPath: "/nonexistent-stroke-test"))!
        precondition(missing.contains("пока нет данных") && !missing.contains("<script"))
        // The final script is the application's own animation setup. Its data
        // comes from the real bundled character; drawing itself is stubbed.
        let script = html.components(separatedBy: "<script>").last!.components(separatedBy: "</script>")[0]
        func runtime(_ dark: Bool = false, throwOnCreate: Bool = false) -> JSContext {
            let context = JSContext()!
            context.exceptionHandler = { _, exception in
                fatalError(exception?.toString() ?? "JavaScript error")
            }
            context.evaluateScript("""
            var elements = {writer:{hidden:false}, status:{hidden:false,textContent:''}};
            var receivedCharacter, receivedOptions, animationCount = 0, rejection;
            var document = {getElementById:function(id) {return elements[id];}};
            var window = {matchMedia:function() {return {matches:\(dark)};}};
            var HanziWriter = {create:function(id, character, options) {
                if (\(throwOnCreate)) throw new Error('failed');
                receivedCharacter=character; receivedOptions=options;
                return {animateCharacter:function() {animationCount++; return {catch:function(fn) {rejection=fn;}};}};
            }};
            """)
            context.evaluateScript(script)
            return context
        }
        func require(_ context: JSContext, _ condition: String) {
            precondition(context.evaluateScript(condition)!.toBool(), condition)
        }
        let success = runtime()
        success.evaluateScript("receivedOptions.onLoadCharDataSuccess()")
        require(success, "receivedCharacter==='好' && animationCount===1 && elements.status.hidden && !elements.writer.hidden")
        require(success, "receivedOptions.charDataLoader().strokes.length>0 && receivedOptions.charDataLoader().medians.length>0")
        require(success, "receivedOptions.strokeColor==='#1E1A16' && receivedOptions.outlineColor==='#E3D7C2'")
        require(runtime(true), "receivedOptions.strokeColor==='#EDE4D3' && receivedOptions.outlineColor==='#3A322A'")
        for failure in ["receivedOptions.onLoadCharDataError()", "rejection()"] {
            let context = runtime(); context.evaluateScript(failure)
            require(context, "elements.writer.hidden && !elements.status.hidden && elements.status.textContent.includes('Не удалось')")
        }
        require(runtime(throwOnCreate:true), "elements.writer.hidden && elements.status.textContent.includes('Не удалось')")
        print("PASS: Han extraction, arbitrary word lengths, literal validation, real bundled data, missing-data fallback")
        print("PASS: inline-only HTML/CSP, animation setup, light/dark colors and recoverable error states")
    }
}
'''
swift = ARTIFACTS / "StrokeChecks.swift"
binary = ARTIFACTS / "stroke-checks"
swift.write_text(source)
subprocess.run([
    "/usr/bin/swiftc", "-parse-as-library", "-framework", "JavaScriptCore",
    "-module-cache-path", str(ROOT / ".verification/swift-module-cache"),
    str(swift), "-o", str(binary),
], check=True)
subprocess.run([str(binary), str(ROOT / "StrokeAssets")], check=True)
