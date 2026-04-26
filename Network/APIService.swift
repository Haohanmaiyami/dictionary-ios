//
//  APIService.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "http://127.0.0.1:8000"
    
    private init() {}
    
    func search(query: String) async throws -> SearchResponse {
        // 1. Кодируем query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        // 2. Собираем URL
        let urlString = "\(baseURL)/api/search?q=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        // 3. Делаем запрос
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // 4. Проверка ответа
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // 5. Декодируем JSON
        let decoder = JSONDecoder()
        let result = try decoder.decode(SearchResponse.self, from: data)
        
        return result
    }
    
    func analyzeChinese(text: String) async throws -> AIAnalyzeResponse {
        let url = URL(string: "\(baseURL)/api/ai/analyze")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = AIAnalyzeRequest(text: text)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        do {
            let decoded = try JSONDecoder().decode(AIAnalyzeResponse.self, from: data)
            return decoded
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "NO DATA"
            throw NSError(
                domain: "AI_DEBUG",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "RAW JSON:\n\(raw)\n\nERROR:\n\(error)"
                ]
            )
        }
    }
        
    func translateRuToCn(text: String) async throws -> AITranslateRuToCnResponse {
        let url = URL(string: "\(baseURL)/api/ai/translate-ru-to-cn")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AITranslateRuToCnRequest(text: text)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(AITranslateRuToCnResponse.self, from: data)
    }
}

