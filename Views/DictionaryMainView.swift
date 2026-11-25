//
//  DictionaryMainView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI
import UIKit

struct DictionaryMainView: View {
    /// Switches to the History tab («Вся история»).
    var showHistory: () -> Void = {}

    @State private var query: String = ""
    @State private var results: [Entry] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isShowingPrivacy = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchID = UUID()
    /// Query of the last search that finished; nil while the user edits the field.
    @State private var searchedQuery: String?
    /// An example chip sets the query first; the search starts once the change lands.
    @State private var pendingSearch: String?

    @ObservedObject private var history = HistoryStore.shared
    @FocusState private var isSearchFieldFocused: Bool

    private static let examples = ["你好", "nihao", "привет"]

    /// The landscape and the large title are shown on the idle screen only;
    /// typing or searching moves the field to the top.
    private var showsHero: Bool {
        !isSearchFieldFocused && query.isEmpty && !isLoading && errorMessage == nil && results.isEmpty
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        InkScreenHeader(label: "汉俄词典") {
                            InkInfoButton { isShowingPrivacy = true }
                        }

                        if showsHero {
                            VStack(alignment: .leading, spacing: 6) {
                                InkLargeTitle(text: "Словарь")
                                InkSubtitle(text: "Китайский ⇄ русский")
                            }
                            .padding(.top, 4)
                            Color.clear
                                .frame(height: heroGap(width: geometry.size.width))
                        }

                        searchField
                            .padding(.top, showsHero ? 0 : 8)

                        content
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignment: .top) {
                        if showsHero {
                            Image("InkHero")
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: showsHero)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .background(Ink.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle("Словарь")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Готово") {
                        hideKeyboard()
                    }
                }
            }
            .onChange(of: query) { newValue in
                cancelSearch()
                results = []
                errorMessage = nil
                searchedQuery = nil
                if let pending = pendingSearch, pending == newValue {
                    pendingSearch = nil
                    startSearch()
                }
            }
            .onDisappear { cancelSearch() }
            .sheet(isPresented: $isShowingPrivacy) {
                NavigationStack { PrivacyDisclosureView() }
            }
        }
    }

    /// Space between the subtitle and the search field, so the field sits on
    /// the misty lower edge of the landscape at any screen width.
    private func heroGap(width: CGFloat) -> CGFloat {
        let fieldTop = width * 307 / 390
        return max(24, fieldTop - 124)
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Ink.ink)
                .accessibilityHidden(true)

            TextField(
                "Введите слово",
                text: $query,
                prompt: Text("Иероглифы, пиньинь или слово")
                    .font(InkFont.serif(15, italic: true))
                    .foregroundColor(Ink.muted)
            )
            .font(InkFont.serif(20, .medium))
            .foregroundStyle(Ink.ink)
            .tint(Ink.cinnabar)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($isSearchFieldFocused)
            .onSubmit {
                hideKeyboard()
                startSearch()
            }

            if !query.isEmpty {
                Button {
                    hideKeyboard()
                    query = ""
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(Ink.muted)
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить")
            }

            Button {
                hideKeyboard()
                startSearch()
            } label: {
                ZStack {
                    Circle().fill(Ink.cinnabar)
                    if isLoading {
                        ProgressView()
                            .tint(Ink.sealText)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Ink.sealText)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel("Поиск")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 56)
        .background(Capsule().fill(Ink.card))
        .overlay(
            Capsule().stroke(isSearchFieldFocused ? Ink.cinnabar : Ink.line,
                             lineWidth: isSearchFieldFocused ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 8)
    }

    // MARK: - Content below the field

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingRows
        } else if let errorMessage {
            InkEmptyState(image: "InkEmptyBridge", title: "Ошибка", message: errorMessage)
        } else if !results.isEmpty {
            resultRows
        } else if searchedQuery != nil {
            InkEmptyState(
                image: "InkEmptyScroll",
                title: "Ничего не найдено",
                message: "Попробуйте иероглифы, пиньинь или другое русское слово"
            )
        } else {
            home
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Например")
                        .font(InkFont.serif(13, relativeTo: .footnote))
                        .foregroundStyle(Ink.muted)
                    ForEach(Self.examples, id: \.self) { example in
                        Button {
                            searchExample(example)
                        } label: {
                            exampleChip(example)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Найти «\(example)»")
                    }
                }
                .padding(.vertical, 2)
            }
            .padding(.top, 10)

            if history.items.isEmpty {
                Text("Поиск слов и ИИ анализ")
                    .font(InkFont.serif(15, italic: true))
                    .foregroundStyle(Ink.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
            } else {
                InkSectionLabel(title: "Недавние") {
                    Button("Вся история", action: showHistory)
                        .font(InkFont.serif(13, .medium, relativeTo: .footnote))
                        .foregroundStyle(Ink.cinnabar)
                        .fixedSize()
                        .frame(minHeight: 44)
                }
                .padding(.top, 14)

                ForEach(history.items.prefix(3)) { saved in
                    let entry = saved.toEntry()
                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                        InkEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exampleChip(_ text: String) -> some View {
        let isChinese = text.range(of: "\\p{Han}", options: .regularExpression) != nil
        let isRussian = text.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil
        return Text(text)
            .font(isChinese ? InkFont.chinese(16)
                  : InkFont.serif(isRussian ? 14 : 17, .medium, italic: !isRussian))
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(Ink.card))
            .overlay(Capsule().stroke(Ink.line, lineWidth: 1))
            .padding(.vertical, 5)
            .contentShape(Rectangle())
    }

    private var loadingRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            metaRow("ИЩУ…")
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: 14) {
                    InkSkeletonBar(width: [60, 48, 66, 56, 44][index], height: 22)
                        .frame(width: 84, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        InkSkeletonBar(width: [70, 60, 76, 64, 58][index])
                        InkSkeletonBar(width: [170, 140, 190, 130, 160][index])
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Ink.lineSoft).frame(height: 1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ищу...")
    }

    private var resultRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            metaRow(InkText.words(results.count).uppercased())
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                        InkEntryRow(entry: entry, highlight: highlightTerm, isProminent: index == 0)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, index == 0 ? 6 : 0)
                }
            }
        }
    }

    private func metaRow(_ leading: String) -> some View {
        HStack {
            Text(leading)
            Spacer()
            Text(directionLabel)
        }
        .font(InkFont.serif(11.5, .medium, relativeTo: .caption1))
        .tracking(1.8)
        .foregroundStyle(Ink.muted)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .padding(.horizontal, 2)
    }

    // MARK: - Labels

    private var directionLabel: String {
        let text = searchedQuery ?? query
        if text.range(of: "\\p{Han}", options: .regularExpression) != nil {
            return "中文 → РУССКИЙ"
        }
        if text.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil {
            return "РУССКИЙ → 中文"
        }
        return "ПИНЬИНЬ → 中文"
    }

    /// Russian queries are highlighted inside the translations.
    private var highlightTerm: String? {
        guard let searchedQuery,
              searchedQuery.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil else { return nil }
        return searchedQuery
    }

    // MARK: - Actions

    private func hideKeyboard() {
        isSearchFieldFocused = false
    }

    private func searchExample(_ example: String) {
        hideKeyboard()
        if query == example {
            startSearch()
        } else {
            pendingSearch = example
            query = example
        }
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
                searchedQuery = trimmedQuery
            } catch {
                guard !Task.isCancelled, searchID == requestID else { return }
                errorMessage = NetworkErrorPresentation.message(for: error)
                results = []
                if errorMessage != nil {
                    searchedQuery = trimmedQuery
                }
            }
        }
    }
}
