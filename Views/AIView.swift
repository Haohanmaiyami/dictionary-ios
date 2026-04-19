import SwiftUI
import UIKit

struct AIView: View {
    @State private var text: String = ""
    @State private var literal: String = ""
    @State private var natural: String = ""
    @State private var pinyin: String = ""
    @State private var keywords: [String] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var isCNMode = true
    @State private var dictionaryHits: [AIDictionaryHit] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                // MODE SWITCH
                Picker("Mode", selection: $isCNMode) {
                    Text("CN -> RU").tag(true)
                    Text("RU -> CN").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // INPUT
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .padding(8)
                        .scrollContentBackground(.hidden)

                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Введите текст...")
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 120)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5))
                )
                .padding(.horizontal)

                // BUTTON
                Button(isCNMode ? "Перевести (CN -> RU)" : "Перевести (RU -> CN)") {
                    hideKeyboard()
                    Task {
                        await analyze()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // STATES
                if isLoading {
                    ProgressView("Анализ...")
                } else if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                } else if !literal.isEmpty || !natural.isEmpty || !pinyin.isEmpty {

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {

                            // LITERAL
                            if !literal.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Буквальный перевод")
                                        .font(.headline)

                                    Text(literal)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }

                            // NATURAL
                            if !natural.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Естественный перевод")
                                        .font(.headline)

                                    Text(natural)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }

                            // PINYIN
                            if !pinyin.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Пиньинь")
                                        .font(.headline)

                                    Text(formatPinyin(pinyin))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }

                            // KEYWORDS (AI)
                            if !keywords.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ключевые слова")
                                        .font(.headline)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(keywords, id: \.self) { word in
                                                Text(word)
                                                    .padding(8)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }

                            // DICTIONARY HITS
                            if !dictionaryHits.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Словарь")
                                        .font(.headline)

                                    ForEach(dictionaryHits) { hit in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(hit.hanzi ?? "—")
                                                .font(.title3)
                                                .fontWeight(.bold)

                                            if let pinyin = hit.pinyin, !pinyin.isEmpty {
                                                Text(formatPinyin(pinyin))
                                                    .foregroundColor(.secondary)
                                            }

                                            if let ru = hit.ru, !ru.isEmpty {
                                                Text(ru)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemGray5))
                                        .cornerRadius(12)
                                    }
                                }
                            }

                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("AI")
            .onTapGesture {
                hideKeyboard()
            }
        }
    }



    func formatPinyin(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "？", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }


    // MARK: - Logic

    func analyze() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        error = nil

        // очищаем
        literal = ""
        natural = ""
        pinyin = ""
        keywords = []
        dictionaryHits = []

        do {
            let response = try await APIService.shared.analyzeChinese(text: trimmed)

            literal = response.literal
            natural = response.natural
            pinyin = response.pinyin
            keywords = response.keywords
            dictionaryHits = response.dictionaryHits
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Keyboard

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
