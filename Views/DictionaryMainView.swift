//
//  DictionaryMainView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI

struct DictionaryMainView: View {
    @State private var query: String = ""
    @State private var results: [Entry] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                HStack {
                    TextField("Введите слово", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await performSearch()
                            }
                        }
                    
                    if !query.isEmpty {
                        Button("Очистить") {
                            query = ""
                            results = []
                            errorMessage = nil
                        }
                        .buttonStyle(.bordered)
                        .font(.subheadline)
                        .tint(.gray)
                    }
                }
                .padding(.horizontal)
                
                Button("Поиск") {
                    Task {
                        await performSearch()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                
                
                // Логика состояний
                
                
                if isLoading {
                    Spacer()
                    ProgressView("Ищу...")
                    Spacer()
                    
                } else if let errorMessage = errorMessage {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("Ошибка")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                } else if results.isEmpty && !query.isEmpty {
                    Spacer()
                    
                    Text("Ничего не найдено")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                } else {
                    List(results) { entry in
                        NavigationLink(destination: EntryDetailView(entry: entry)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.hanzi ?? "—")
                                    .font(.headline)
                                
                                if let pinyin = entry.pinyin, !pinyin.isEmpty {
                                    Text(pinyin)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(
                                    (entry.ru ?? "Без перевода")
                                        .replacingOccurrences(of: "<br>", with: " ")
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    )
                                    .font(.subheadline)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Словарь")
        }
    }
        
    func performSearch() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await APIService.shared.search(query: trimmedQuery)
            results = response.results
        } catch {
            errorMessage = "Ошибка: \(error.localizedDescription)"
            results = []
        }
        
        isLoading = false
    }
}


