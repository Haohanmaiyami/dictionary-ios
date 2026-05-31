//
//  APIService.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import Foundation

class APIService {
    static let shared = APIService()

    private let baseURL = "http://45.12.231.230:8001"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180

        return URLSession(configuration: config)
    }()

    private init() {}

    // добавили параметр limit
    // Раньше было: func search(query: String)
    // Теперь: func search(query: String, limit: Int = 20)
    // Это нужно, чтобы iOS не просил слишком много результатов
    func search(query: String, limit: Int = 20) async throws -> SearchResponse {

        // URL теперь собираем через URLComponents
        // Так надежнее, чем вручную кодировать строку
        var components = URLComponents(string: "\(baseURL)/api/search")

        // добавили limit в query parameters
        // Получится так:
        // /api/search?q=难听&limit=20
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        // используем URLRequest, чтобы поставить отдельный timeout
        // Для обычного словаря 180 секунд — слишком много.
        // Если словарь грузится больше 20 сек, это уже backend-проблема.
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        // вместо session.data(from: url)
        // используем session.data(for: request), потому что у request есть timeout
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }

    func analyzeChinese(text: String) async throws -> AIAnalyzeResponse {
        let url = URL(string: "\(baseURL)/api/ai/analyze")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AIAnalyzeRequest(text: text)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(AITranslateRuToCnResponse.self, from: data)
    }

    func fetchEntry(id: Int) async throws -> Entry {
        let url = URL(string: "\(baseURL)/api/entry/\(id)")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(Entry.self, from: data)
    }
}
