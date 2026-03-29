//
//  APIService.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import Foundation

class APIService {
    static let shared = APIService()
    
    private let baseURL = "http://192.168.1.175:8000"
    
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
}
