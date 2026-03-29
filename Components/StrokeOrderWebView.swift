//
//  StrokeOrderWebView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/28/26.
//

import SwiftUI
import WebKit

struct StrokeOrderWebView: UIViewRepresentable {
    let hanzi: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let firstCharacter = String(hanzi.prefix(1))

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.jsdelivr.net/npm/hanzi-writer@3.5/dist/hanzi-writer.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    background: transparent;
                }
                #writer {
                    width: 220px;
                    height: 220px;
                }
            </style>
        </head>
        <body>
            <div id="writer"></div>

            <script>
                const writer = HanziWriter.create('writer', '\(firstCharacter)', {
                    width: 220,
                    height: 220,
                    padding: 5,
                    showOutline: true,
                    showCharacter: false,
                    strokeAnimationSpeed: 1,
                    delayBetweenStrokes: 200
                });

                writer.animateCharacter();
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}
