//
//  Dictinary.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI

struct DictionaryView: View {
    var body: some View {
        TabView {
            
            DictionaryMainView()
                .tabItem {
                    Label("Словарь", systemImage: "book")
                }
            
            AIView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Избранное", systemImage: "star.fill")
                }
            
            HistoryView()
                .tabItem {
                    Label("История", systemImage: "clock")
                }
        }
    }
}

enum AIPrivacySettings {
    static let consentKey = "aiThirdPartyConsentGranted"
}

struct PrivacyDisclosureView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AIPrivacySettings.consentKey) private var aiConsentGranted = false

    private let privacyPolicyURL = URL(string: "https://31.129.45.131/privacy")!

    var body: some View {
        Form {
            Section("Политика конфиденциальности") {
                Link("Открыть политику конфиденциальности", destination: privacyPolicyURL)
            }

            Section("ИИ-перевод") {
                Text("Для ИИ-анализа и перевода введённый вами текст отправляется на сервер Chinese Bridge, а затем в Selectel Token Factory. Без вашего согласия ИИ-запрос не отправляется. Поиск по словарю работает без этого согласия.")
                Text(aiConsentGranted ? "Согласие дано" : "Согласие не дано")
                    .foregroundStyle(.secondary)
                if aiConsentGranted {
                    Button("Отозвать согласие на ИИ") {
                        aiConsentGranted = false
                    }
                }
            }
        }
        .navigationTitle("Конфиденциальность")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") { dismiss() }
            }
        }
    }
}
