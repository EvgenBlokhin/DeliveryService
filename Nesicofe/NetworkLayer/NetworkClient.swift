//
//  NetworkClient.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation
// NetworkClient
//Что он должен делать (высокоуровнево):
//    •    Принимать request descriptor (endpoint, params, expected response type).
//    •    Взаимодействовать с HTTPTransport для выполнения запроса.
//    •    Выполнять общую обработку ответов:
//    •    Перевести network errors -> domain errors,
//    •    Обрабатывать HTTP-коды (2xx OK, 401 Unauthorized и т.д.),
//    •    При 401 (или другой логике) делегировать refresh механизму (через AuthService/interceptor) или пробросить ошибку.
//    •    Декодировать Data в T: Decodable через JSONDecoder (или вернуть сырой Data по запросу).
//    •    Поддерживать опции: request<T>(endpoint:, requiresAuth: Bool) — если требуется авторизация, добавить header (через AuthInterceptor или AuthService).
//    •    Возможна поддержка middleware/interceptor pipeline (logging, retry, caching, auth).
final class NetworkClient {
    private let transport: HTTPTransport
    private let authService: AuthService
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let refreshCoordinator = RefreshCoordinator() // optional, we use authService's singleflight
    private let preemptiveThreshold: TimeInterval = 30 // seconds

    init(transport: HTTPTransport, authService: AuthService) {
        self.transport = transport
        self.authService = authService
        jsonDecoder.dateDecodingStrategy = .iso8601
        jsonEncoder.dateEncodingStrategy = .iso8601
    }

    func request<T: Decodable>(path: String,
                               method: String = "GET",
                               body: Encodable? = nil,
                               requiresAuth: Bool = true) async throws -> T {
        // Preemptive refresh if token will expire soon
        if requiresAuth {
            if let expiry = await authService.getAccessTokenExpiry() {
                if expiry.timeIntervalSinceNow < preemptiveThreshold {
                    do {
                        try await authService.refreshTokenSingleflight()
                    } catch {
                        // cannot refresh — bubble up
                        throw error
                    }
                }
            }
        }

        // Build request with current token (token could be nil)
        var headers: [String: String] = [:]
        if requiresAuth, let token = await authService.getAccessToken() {
            headers["Authorization"] = "Bearer \(token)"
        }

        let req = try transport.makeRequest(path: path, method: method, body: body, headers: headers)
        do {
            let (data, http) = try await transport.send(req)
            if http.statusCode == 401 && requiresAuth {
                // Attempt single-flight refresh once, then retry request
                do {
                    try await authService.refreshTokenSingleflight()
                } catch {
                    throw error // refresh failed -> bubble up
                }
                // rebuild headers with new token
                var retryHeaders = headers
                if let newToken = await authService.getAccessToken() {
                    retryHeaders["Authorization"] = "Bearer \(newToken)"
                }
                let retryReq = try transport.makeRequest(path: path, method: method, body: body, headers: retryHeaders)
                let (retryData, retryHttp) = try await transport.send(retryReq)
                guard (200...299).contains(retryHttp.statusCode) else {
                    throw NetworkError.httpError(status: retryHttp.statusCode, data: retryData)
                }
                let decoded = try jsonDecoder.decode(T.self, from: retryData)
                return decoded
            }

            guard (200...299).contains(http.statusCode) else {
                throw NetworkError.httpError(status: http.statusCode, data: data)
            }
            let decoded = try jsonDecoder.decode(T.self, from: data)
            return decoded
        } catch {
            throw error
        }
    }

    enum NetworkError: Error {
        case httpError(status: Int, data: Data?)
    }
}
