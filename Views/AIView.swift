//
//  AIView.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import SwiftUI
import UIKit

struct AIView: View {
    @State private var text: String = ""
    @State private var result: String = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var isCNMode = true
    @State private var dictionaryHits: [AIDictionaryHit] = []
    @State private var showCopiedMessage = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Picker("Mode", selection: $isCNMode) {
                    Text("CN -> RU").tag(true)
                    Text("RU -> CN").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
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
                
                Button(isCNMode ? "Перевести (CN -> RU)" : "Перевести (RU -> CN)") {
                    hideKeyboard()
                    Task {
                        await analyze()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                if isLoading {
                    ProgressView("Анализ...")
                } else if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                } else if !result.isEmpty {
                    ScrollView {
                        let sections = parseAIResult(result)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(sections, id: \.title) { section in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(section.title)
                                            .font(.headline)
                                        
                                        Text(section.content)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)                                }
                            }
                            
                            Button(showCopiedMessage ? "Скопировано" : "Скопировать результат") {
                                let sections = parseAIResult(result)
                                let formatted = sections
                                        .map { section in
                                            "\(section.title)\n\(section.content)"
                                        }
                                        .joined(separator: "\n\n")
                                UIPasteboard.general.string = formatted
                                showCopiedMessage = true
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showCopiedMessage = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(showCopiedMessage ? .green : .blue)
                            
                            
                            if !dictionaryHits.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Ключевые слова")
                                        .font(.headline)
                                    
                                    ForEach(dictionaryHits) { hit in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(hit.hanzi ?? "—")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                            
                                            if let pinyin = hit.pinyin, !pinyin.isEmpty {
                                                Text(pinyin)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            if let ru = hit.ru, !ru.isEmpty {
                                                Text(ru)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    func analyze() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isLoading = true
        error = nil
        result = ""
        dictionaryHits = []
        
        do {
            if isCNMode {
                let response = try await APIService.shared.analyzeChinese(text: trimmed)
                result = response.analysis
                dictionaryHits = response.dictionaryHits
            } else {
                let response = try await APIService.shared.translateRuToCn(text: trimmed)
                result = response.translation
                dictionaryHits = []
            }
        } catch let err {
            error = err.localizedDescription
        }
        
        isLoading = false
    }
    
    func parseAIResult(_ text: String) -> [(title: String, content: String)] {
        let parts = text.components(separatedBy: "\n\n")
        
        return parts.map { part in
            let lines = part.components(separatedBy: "\n")
            let title = lines.first ?? ""
            let content = lines.dropFirst().joined(separator: "\n")
            return (title, content)
        }
    }
}

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
