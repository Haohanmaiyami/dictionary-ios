import Foundation
import SwiftUI
import UIKit
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

    static func html(for character: String, assetsURL: URL? = nil, size: Int = 220) -> String? {
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
            <style>
                html, body { height:100%; margin:0; }
                body { display:flex; align-items:center; justify-content:center; padding:0 14px; box-sizing:border-box;
                       font:13px/1.45 -apple-system; text-align:center; background:transparent; color:#6B6052; }
                @media (prefers-color-scheme: dark) { body { color:#9C907E; } }
            </style>
            </head><body>
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
            html, body { height:100%; margin:0; }
            body { background:transparent; font:13px/1.45 -apple-system; text-align:center; position:relative; }
            #writer { width:\(size)px; height:\(size)px; margin:auto; }
            #status { position:absolute; inset:0; margin:0; padding:0 14px; display:flex; align-items:center;
                      justify-content:center; box-sizing:border-box; color:#6B6052; }
            #status[hidden] { display:none; }
            @media (prefers-color-scheme: dark) { #status { color:#9C907E; } }
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
                width:\(size), height:\(size), padding:\(max(5, size / 12)),
                showOutline:true, showCharacter:false,
                strokeAnimationSpeed:1, delayBetweenStrokes:200,
                strokeColor:dark ? '#EDE4D3' : '#1E1A16',
                outlineColor:dark ? '#3A322A' : '#E3D7C2',
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

/// Stroke-order header of a word card. A one-character word shows the
/// animation at once; longer words show their characters as copybook tiles,
/// and tapping a tile animates that character (the same picker as before).
struct StrokeOrderSection: View {
    let characters: [String]
    var pinyin: String? = nil

    @State private var selectedIndex = 0
    @State private var replayID = UUID()

    private var isMultiple: Bool { characters.count > 1 }
    private var canvasSize: CGFloat { isMultiple ? 150 : 170 }
    private var tileSize: CGFloat { characters.count > 5 ? 50 : 58 }

    private var pinyinSize: CGFloat {
        guard isMultiple else { return 44 }
        return (pinyin?.count ?? 0) > 12 ? 19 : 30
    }

    var body: some View {
        if characters.indices.contains(selectedIndex) {
            VStack(alignment: .leading, spacing: 16) {
                if isMultiple {
                    tileStrip
                }
                HStack(alignment: .center, spacing: 18) {
                    canvas
                    VStack(alignment: .leading, spacing: 6) {
                        if let pinyin, !pinyin.isEmpty {
                            Text(pinyin)
                                .font(InkFont.serif(pinyinSize, .semibold, italic: true, relativeTo: .title1))
                                .foregroundStyle(Ink.ink)
                                .lineLimit(4)
                                .minimumScaleFactor(0.6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(isMultiple ? "ИЕРОГЛИФ \(selectedIndex + 1) ИЗ \(characters.count)" : "ПОРЯДОК ЧЕРТ")
                            .font(InkFont.serif(11.5, .medium, relativeTo: .caption1))
                            .tracking(1.8)
                            .foregroundStyle(Ink.muted)
                            .accessibilityLabel(isMultiple
                                ? "Иероглиф \(selectedIndex + 1) из \(characters.count)"
                                : "Порядок черт")
                        Button {
                            replayID = UUID()
                        } label: {
                            Label("Повторить", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(InkOutlineButtonStyle())
                        .padding(.top, 6)
                        .accessibilityIdentifier("stroke-replay")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canvas: some View {
        ZStack {
            Rectangle().fill(Ink.card)
            InkMiZiGrid()
            StrokeOrderWebView(hanzi: characters[selectedIndex], size: Int(canvasSize))
                .id(replayID)
                .accessibilityIdentifier("stroke-canvas")
        }
        .frame(width: canvasSize, height: canvasSize)
        .overlay(Rectangle().stroke(Ink.cinnabar, lineWidth: 1.5))
    }

    private var tileStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(characters.indices, id: \.self) { index in
                        Button {
                            selectedIndex = index
                            replayID = UUID()
                            withAnimation { proxy.scrollTo(index, anchor: .center) }
                        } label: {
                            StrokeCharacterTile(
                                character: characters[index],
                                isSelected: index == selectedIndex,
                                size: tileSize
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Иероглиф \(characters[index]), \(index + 1) из \(characters.count)")
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                        .accessibilityIdentifier("stroke-character-\(index)")
                        .id(index)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 12)
                .padding(.horizontal, 2)
            }
            .mask {
                // Long phrases scroll sideways; the trailing edge fades out.
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: characters.count > 6 ? 0.86 : 1),
                        .init(color: characters.count > 6 ? .clear : .black, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }
}

private struct StrokeCharacterTile: View {
    let character: String
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Ink.card)
            InkTianZiGrid().padding(1)
            Text(character)
                .font(InkFont.chinese(size * 0.6))
                .foregroundStyle(isSelected ? Ink.cinnabar : Ink.ink)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Ink.cinnabar : Ink.line, lineWidth: isSelected ? 1.5 : 1)
        )
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(Ink.cinnabar)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(45))
                    .offset(y: 8)
            }
        }
        .shadow(color: isSelected ? Ink.cinnabar.opacity(0.25) : .clear, radius: 6, y: 4)
        .contentShape(Rectangle())
    }
}

struct StrokeOrderWebView: UIViewRepresentable {
    let hanzi: String
    var size: Int = 220

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
        webView.loadHTMLString(StrokeOrderContent.html(for: hanzi, size: size) ?? "", baseURL: nil)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
    }
}
