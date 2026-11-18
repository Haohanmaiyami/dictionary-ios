import Foundation
import SwiftUI
import WebKit

enum StrokeOrderContent {
    // Match base Han scalars, including supplementary planes and compatibility
    // characters. Ignore punctuation, Latin text, emoji and variation selectors.
    private static let hanCharacters = try! NSRegularExpression(
        pattern: "[\\p{Unified_Ideograph}\\u3007\\uF900-\\uFAFF]"
    )

    static func characters(in text: String) -> [String] {
        hanCharacters.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { match in
                Range(match.range, in: text).map { String(text[$0]) }
            }
    }

    static func html(for character: String, assetsURL: URL? = nil) -> String? {
        // Only a single extracted Han scalar may enter the HTML/JavaScript.
        guard characters(in: character) == [character] else { return nil }
        let assets = assetsURL ?? Bundle.main.resourceURL?.appendingPathComponent("StrokeAssets")
        let key = String(character.unicodeScalars.first!.value, radix: 16).uppercased()
        guard let assets,
              let library = try? String(contentsOf: assets.appendingPathComponent("hanzi-writer.min.js"), encoding: .utf8),
              let data = try? Data(contentsOf: assets.appendingPathComponent("Characters/\(key).json")),
              let object = try? JSONSerialization.jsonObject(with: data),
              let safeData = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: safeData, encoding: .utf8) else {
            return """
            <!doctype html><html lang="ru"><head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
            <meta name="color-scheme" content="light dark">
            </head><body style="font:16px -apple-system;text-align:center;background:transparent">
            Для этого иероглифа пока нет данных порядка черт.
            </body></html>
            """
        }
        let encoded = String(data: try! JSONEncoder().encode(character), encoding: .utf8)!
        // All scripts/data are bundled. Even the library's unused default CDN
        // loader cannot connect: CSP blocks every network request.
        let safeLibrary = library.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
        let inlineData = json.replacingOccurrences(of: "<", with: "\\u003C")
        return """
        <!doctype html><html lang="ru"><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'none'">
        <meta name="color-scheme" content="light dark">
        <style>
            body { margin:0; background:transparent; font:15px -apple-system; text-align:center; }
            #writer { width:220px; height:220px; margin:auto; }
            #status { color:GrayText; margin:0; }
        </style></head><body>
        <div id="writer" role="img" aria-label="Порядок черт: \(character)"></div>
        <p id="status" role="status">Загрузка…</p>
        <script>
        \(safeLibrary)
        </script>
        <script>
        const status = document.getElementById('status');
        const data = \(inlineData);
        function unavailable() {
            document.getElementById('writer').hidden = true;
            status.hidden = false;
            status.textContent = 'Не удалось показать порядок черт. Нажмите «Повторить».';
        }
        try {
            const dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            const writer = HanziWriter.create('writer', \(encoded), {
                width:220, height:220, padding:5,
                showOutline:true, showCharacter:false,
                strokeAnimationSpeed:1, delayBetweenStrokes:200,
                strokeColor:dark ? '#E5E5EA' : '#555555',
                outlineColor:dark ? '#48484A' : '#DDDDDD',
                charDataLoader:function() { return data; },
                onLoadCharDataSuccess:function() { status.hidden = true; },
                onLoadCharDataError:unavailable
            });
            writer.animateCharacter().catch(unavailable);
        } catch (_) { unavailable(); }
        </script></body></html>
        """
    }
}

struct StrokeOrderSection: View {
    let characters: [String]
    @State private var selectedIndex = 0
    @State private var replayID = UUID()

    var body: some View {
        if characters.indices.contains(selectedIndex) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Порядок черт")
                    .font(.headline)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 8) {
                            ForEach(characters.indices, id: \.self) { index in
                                Button {
                                    selectedIndex = index
                                    replayID = UUID()
                                    withAnimation { proxy.scrollTo(index, anchor: .center) }
                                } label: {
                                    Text(characters[index])
                                        .font(.title2)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .foregroundStyle(index == selectedIndex ? Color.white : Color.primary)
                                        .background(index == selectedIndex ? Color.accentColor : Color(.systemGray5))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Иероглиф \(characters[index]), \(index + 1) из \(characters.count)")
                                .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                                .accessibilityIdentifier("stroke-character-\(index)")
                                .id(index)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                StrokeOrderWebView(hanzi: characters[selectedIndex])
                    .id(replayID)
                    .frame(height: 240)
                    .accessibilityIdentifier("stroke-canvas")

                Button {
                    replayID = UUID()
                } label: {
                    Label("Повторить", systemImage: "arrow.clockwise")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("stroke-replay")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct StrokeOrderWebView: UIViewRepresentable {
    let hanzi: String

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedCharacter: String?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Inline document only; links and remote navigations are denied.
            let url = navigationAction.request.url
            decisionHandler(url == nil || url?.absoluteString == "about:blank" ? .allow : .cancel)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedCharacter != hanzi else { return }
        context.coordinator.loadedCharacter = hanzi
        webView.loadHTMLString(StrokeOrderContent.html(for: hanzi) ?? "", baseURL: nil)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
    }
}
