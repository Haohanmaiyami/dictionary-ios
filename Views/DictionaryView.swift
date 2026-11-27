//
//  Dictinary.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI
import UIKit

struct DictionaryView: View {
    private enum Tab: Hashable {
        case dictionary, ai, favorites, history
    }

    @State private var selectedTab: Tab = .dictionary

    var body: some View {
        TabView(selection: $selectedTab) {
            
            DictionaryMainView(showHistory: { selectedTab = .history })
                .tabItem {
                    Label("Словарь", systemImage: "book")
                }
                .tag(Tab.dictionary)
            
            AIView()
                .tabItem {
                    Label("ИИ", systemImage: "sparkles")
                }
                .tag(Tab.ai)
            
            FavoritesView()
                .tabItem {
                    Label("Избранное", systemImage: "star.fill")
                }
                .tag(Tab.favorites)
            
            HistoryView()
                .tabItem {
                    Label("История", systemImage: "clock")
                }
                .tag(Tab.history)
        }
        .tint(Ink.cinnabar)
    }
}

enum AIPrivacySettings {
    static let consentKey = "aiThirdPartyConsentGranted"
}

struct PrivacyDisclosureView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AIPrivacySettings.consentKey) private var aiConsentGranted = false

    private let privacyPolicyURL = URL(string: "https://31.129.45.131/privacy")!
    private let dictionarySourceURL = URL(string: "https://bkrs.info")!

    var body: some View {
        Form {
            Section {
                Link(destination: privacyPolicyURL) {
                    HStack {
                        Text("Открыть политику конфиденциальности")
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right.square")
                            .accessibilityHidden(true)
                    }
                    .font(InkFont.serif(16))
                    .foregroundStyle(Ink.cinnabar)
                }
                .listRowBackground(Ink.card)
            } header: {
                sectionHeader("Политика конфиденциальности")
            }

            Section {
                Text("Для ИИ-анализа и перевода введённый вами текст отправляется на сервер приложения, а затем в Selectel Token Factory. Без вашего согласия ИИ-запрос не отправляется. Поиск по словарю работает без этого согласия.")
                    .font(InkFont.serif(15))
                    .foregroundStyle(Ink.inkSecondary)
                    .listRowBackground(Ink.card)
                HStack(spacing: 10) {
                    Circle()
                        .fill(aiConsentGranted ? Ink.jade : Ink.mutedSoft)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                    Text(aiConsentGranted ? "Согласие дано" : "Согласие не дано")
                        .font(InkFont.serif(15))
                        .foregroundStyle(Ink.ink)
                }
                .listRowBackground(Ink.card)
                if aiConsentGranted {
                    Button("Отозвать согласие на ИИ") {
                        aiConsentGranted = false
                    }
                    .font(InkFont.serif(16, .semibold))
                    .foregroundStyle(Ink.cinnabar)
                    .listRowBackground(Ink.card)
                }
            } header: {
                sectionHeader("ИИ-перевод")
            }

            Section {
                Text("Словарные данные: 大БКРС (Большой китайско-русский словарь) и БРуКС (Большой русско-китайский словарь).")
                    .font(InkFont.serif(15))
                    .foregroundStyle(Ink.inkSecondary)
                    .listRowBackground(Ink.card)
                Link(destination: dictionarySourceURL) {
                    HStack {
                        Text("bkrs.info")
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right.square")
                            .accessibilityHidden(true)
                    }
                    .font(InkFont.serif(16))
                    .foregroundStyle(Ink.cinnabar)
                }
                .listRowBackground(Ink.card)
            } header: {
                sectionHeader("Источник словаря")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Ink.paper.ignoresSafeArea())
        .navigationTitle("Конфиденциальность")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") { dismiss() }
                    .tint(Ink.cinnabar)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(InkFont.serif(11.5, .semibold, relativeTo: .caption1))
            .tracking(2.2)
            .foregroundStyle(Ink.cinnabarDeep)
            .textCase(nil)
            .accessibilityLabel(title)
    }
}
