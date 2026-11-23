//
//  APIService.swift
//  DictionaryApp
//
//  Created by Ayan Kharitonov on 3/17/26.
//

import Foundation

enum AIServiceError: LocalizedError {
    case emptyInput
    case inputTooLong
    case http(status: Int, retryAfterSeconds: Int?, requestID: String? = nil)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Введите текст для перевода."
        case .inputTooLong:
            return "Сократите текст до 1000 символов."
        case let .http(status, retryAfterSeconds, requestID):
            let message: String
            switch status {
            case 400, 422:
                message = "Проверьте текст: от 1 до 1000 символов."
            case 413:
                message = "Текст слишком большой. Сократите его до 1000 символов."
            case 429:
                if let seconds = retryAfterSeconds, seconds > 0 {
                    if seconds < 60 {
                        return NetworkErrorPresentation.withRequestID("Слишком частые запросы. Попробуйте через \(seconds) сек. HTTP \(status).", requestID)
                    }
                    let minutes = 1 + (seconds - 1) / 60
                    return NetworkErrorPresentation.withRequestID("Слишком частые запросы. Попробуйте через \(minutes) мин. HTTP \(status).", requestID)
                }
                message = "Слишком частые запросы. Подождите и попробуйте снова."
            case 503:
                message = "AI сейчас занят или временно недоступен. Попробуйте позже."
            case 504:
                message = "Время ожидания перевода истекло. Попробуйте позже."
            default:
                message = "AI временно недоступен. Попробуйте позже."
            }
            return NetworkErrorPresentation.withRequestID("\(message) HTTP \(status).", requestID)
        }
    }
}

// Safe diagnostics: never include request text, URLs or NSError.userInfo.
enum APIHTTPError: LocalizedError {
    case status(Int, requestID: String? = nil)

    var errorDescription: String? {
        switch self {
        case let .status(code, requestID):
            return NetworkErrorPresentation.withRequestID("Сервер вернул ошибку HTTP \(code). Попробуйте позже.", requestID)
        }
    }
}

enum NetworkErrorPresentation {
    static func requestID(from response: HTTPURLResponse) -> String? {
        guard let raw = response.value(forHTTPHeaderField: "X-Request-ID"),
              let uuid = UUID(uuidString: raw) else { return nil }
        return uuid.uuidString.lowercased()
    }

    static func withRequestID(_ message: String, _ requestID: String?) -> String {
        guard let requestID, let uuid = UUID(uuidString: requestID) else { return message }
        return "\(message) Запрос: \(uuid.uuidString.lowercased())."
    }

    static func message(for error: Error) -> String? {
        if error is CancellationError { return nil }
        if let aiError = error as? AIServiceError {
            return aiError.localizedDescription
        }
        if let httpError = error as? APIHTTPError {
            return httpError.localizedDescription
        }
        if let networkError = error as? URLError {
            let message: String
            switch networkError.code {
            case .cancelled:
                return nil
            case .notConnectedToInternet:
                message = "Нет подключения к интернету. Проверьте соединение."
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                message = "Не удалось подключиться к серверу. Попробуйте позже."
            case .timedOut:
                message = "Время ожидания ответа истекло. Попробуйте позже."
            case .networkConnectionLost:
                message = "Соединение с сервером прервалось. Повторите попытку."
            case .serverCertificateHasBadDate, .serverCertificateUntrusted,
                 .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                message = "Не удалось проверить сертификат сервера. Сообщите код ошибки поддержке."
            case .secureConnectionFailed:
                message = "Не удалось установить защищённое соединение с сервером. Сообщите код ошибки поддержке."
            case .appTransportSecurityRequiresSecureConnection:
                message = "Соединение не соответствует требованиям безопасности iOS. Сообщите код ошибки поддержке."
            default:
                message = "Не удалось выполнить запрос к серверу. Сообщите код ошибки поддержке."
            }
            return "\(message) Код: \(networkError.code.rawValue)."
        }
        if error is DecodingError {
            return "Не удалось прочитать ответ сервера. Попробуйте позже."
        }
        return "Не удалось выполнить запрос. Попробуйте позже."
    }
}

class APIService {
    static let shared = APIService()

    private let baseURL = "https://31.129.45.131"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180

        return URLSession(configuration: config)
    }()

    private init() {}

    static let maximumAITextLength = 1000

    static func validateAIInput(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.emptyInput
        }
        // Count Unicode scalars to match the Python API's character limit.
        guard text.unicodeScalars.count <= maximumAITextLength else {
            throw AIServiceError.inputTooLong
        }
    }

    static func validateDictionaryResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            throw APIHTTPError.status(httpResponse.statusCode,
                                      requestID: NetworkErrorPresentation.requestID(from: httpResponse))
        }
    }

    static func validateAIResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode == 200 else {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Int.init)
            throw AIServiceError.http(
                status: httpResponse.statusCode,
                retryAfterSeconds: retryAfter,
                requestID: NetworkErrorPresentation.requestID(from: httpResponse)
            )
        }
    }


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

        try Self.validateDictionaryResponse(response)

        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }

    func analyzeChinese(text: String) async throws -> AIAnalyzeResponse {
        try Self.validateAIInput(text)

        let url = URL(string: "\(baseURL)/api/ai/analyze")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AIAnalyzeRequest(text: text)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        try Self.validateAIResponse(response)

        return try JSONDecoder().decode(AIAnalyzeResponse.self, from: data)
    }

    func translateRuToCn(text: String) async throws -> AITranslateRuToCnResponse {
        try Self.validateAIInput(text)

        let url = URL(string: "\(baseURL)/api/ai/translate-ru-to-cn")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AITranslateRuToCnRequest(text: text)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        try Self.validateAIResponse(response)

        return try JSONDecoder().decode(AITranslateRuToCnResponse.self, from: data)
    }

    func fetchEntry(id: Int) async throws -> Entry {
        let url = URL(string: "\(baseURL)/api/entry/\(id)")!

        let (data, response) = try await session.data(from: url)

        try Self.validateDictionaryResponse(response)

        return try JSONDecoder().decode(Entry.self, from: data)
    }

    func fetchReferencedEntry(target: String) async throws -> Entry {
        try await DictionaryReferenceResolver.resolve(target: target) { query in
            try await self.search(query: query, limit: 50).results
        }
    }

}
