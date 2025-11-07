//
//  HTTPTransport.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

fileprivate let BASE_API_URL = URL(string: "https://api.yourserver.com/")! // <<< CUSTOMIZE
fileprivate let REQUEST_TIMEOUT: TimeInterval = 30
fileprivate let PREEMPTIVE_REFRESH_THRESHOLD: TimeInterval = 60 // сек до expiry, когда выполняем preemptive refresh
#if DEBUG
fileprivate func log(_ items: Any...) { print("[AuthNet] ", items.map { "\($0)" }.joined(separator: " ")) }
#else
fileprivate func log(_ items: Any...) { /* no-op in production */ }
#endif

final class HTTPTransport {
    private let session: URLSession
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL = BASE_API_URL) {
        self.baseURL = baseURL
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = REQUEST_TIMEOUT
        self.session = URLSession(configuration: cfg)
    }

    /// Сформировать URLRequest. path может быть относительным, с или без начального "/".
    func makeRequest(path: String,
                     method: String = "GET",
                     body: Encodable? = nil,
                     headers: [String: String]? = nil) throws -> URLRequest {
        // Корректно объединяем baseURL и path
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: trimmed, relativeTo: baseURL) else { throw TransportError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let headers = headers {
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        }
        if let body = body {
            // Для безопасности: либо body — конкретная Encodable структура, либо AnyEncodable
            req.httpBody = try encoder.encode(AnyEncodable(body))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    /// Выполнить запрос и вернуть (Data, HTTPURLResponse) или бросить ошибку
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        log("Request:", request.httpMethod ?? "?", request.url?.absoluteString ?? "")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TransportError.invalidResponse }
        log("Response:", http.statusCode, request.url?.absoluteString ?? "")
        return (data, http)
    }

    enum TransportError: Error {
        case invalidURL
        case invalidResponse
    }
}
