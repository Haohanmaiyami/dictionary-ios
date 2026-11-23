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
    @State private var isShowingPrivacy = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchID = UUID()
    
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                HStack {
                    TextField("Введите слово", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            hideKeyboard()
                            startSearch()
                        }
                    
                    if !query.isEmpty {
                        Button("Очистить") {
                            hideKeyboard()
                            query = ""
                            results = []
                            errorMessage = nil
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Button {
                    hideKeyboard()
                    startSearch()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Поиск")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isLoading)
                
                if results.isEmpty && query.isEmpty && !isLoading {
                    Image("dictionary_hero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .opacity(0.9)
                        .padding(.top, 20)

                    Text("Поиск слов и ИИ анализ")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer()

                } else if isLoading {
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
                                Text(entry.displayHeadword)
                                    .font(.headline)
                                
                                if let pinyin = entry.displayPinyin, !pinyin.isEmpty {
                                    Text(pinyin)
                                        .foregroundColor(.gray)
                                }
                                
                                Text(entry.previewText)
                                    .font(.subheadline)
                                    .lineLimit(entry.isRussianHeadword ? 3 : 1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle("Поиск в словаре")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingPrivacy = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Конфиденциальность")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    
                    Button("Готово") {
                        hideKeyboard()
                    }
                }
            }
            .onChange(of: query) { _ in
                cancelSearch()
                results = []
                errorMessage = nil
            }
            .onDisappear { cancelSearch() }
            .sheet(isPresented: $isShowingPrivacy) {
                NavigationStack { PrivacyDisclosureView() }
            }
        }
    }
    
    private func hideKeyboard() {
        isSearchFieldFocused = false
    }
        
    @MainActor
    private func cancelSearch() {
        searchID = UUID()
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
    }

    @MainActor
    private func startSearch() {
        cancelSearch()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            errorMessage = nil
            return
        }
        let requestID = searchID
        isLoading = true
        errorMessage = nil
        searchTask = Task {
            defer {
                if searchID == requestID {
                    isLoading = false
                    searchTask = nil
                }
            }
            do {
                let response = try await APIService.shared.search(query: trimmedQuery, limit: 20)
                guard !Task.isCancelled, searchID == requestID else { return }
                results = response.results
            } catch {
                guard !Task.isCancelled, searchID == requestID else { return }
                errorMessage = NetworkErrorPresentation.message(for: error)
                results = []
            }
        }
    }
}


