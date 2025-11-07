//
//  AuthRemoteDataSourceProtocol.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

protocol AuthRemoteDataSourceProtocol {
    func login(phone: String, password: String) async throws -> TokenResponse
    func register(name: String, phone: String, email: String, password: String, role: String) async throws -> TokenResponse
    func requestPasswordReset(email: String) async throws
    func verifyResetCode(email: String, code: String, newPassword: String) async throws
    func refreshToken(refreshToken: String) async throws -> TokenResponse
}

final class AuthRemoteDataSource: AuthRemoteDataSourceProtocol {
    private let transport: HTTPTransport
    private let decoder = JSONDecoder()

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    func login(phone: String, password: String) async throws -> TokenResponse {
        let body = ["phone": phone, "password": password]
        let req = try transport.makeRequest(path: "auth/login", method: "POST", body: DictionaryEncodable(body))
        let (data, http) = try await transport.send(req)
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.httpError(status: http.statusCode, data: data)
        }
        return try decoder.decode(TokenResponse.self, from: data)
    }

    func register(name: String, phone: String, email: String, password: String, role: String) async throws -> TokenResponse {
        let body: [String: Any] = ["name": name, "phone": phone, "email": email, "password": password, "role": role]
        let req = try transport.makeRequest(path: "auth/register", method: "POST", body: DictionaryEncodable(body))
        let (data, http) = try await transport.send(req)
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.httpError(status: http.statusCode, data: nil)
        }
        return try decoder.decode(TokenResponse.self, from: data)
    }

    func requestPasswordReset(email: String) async throws {
        let req = try transport.makeRequest(path: "auth/password/request", method: "POST", body: DictionaryEncodable(["email": email]))
        let (_, http) = try await transport.send(req)
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.httpError(status: http.statusCode, data: nil)
        }
    }

    func verifyResetCode(email: String, code: String, newPassword: String) async throws {
        let body = ["email": email, "code": code, "new_password": newPassword]
        let req = try transport.makeRequest(path: "auth/password/verify", method: "POST", body: DictionaryEncodable(body))
        let (_, http) = try await transport.send(req)
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.httpError(status: http.statusCode, data: nil)
        }
    }

    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let req = try transport.makeRequest(path: "auth/refresh", method: "POST", body: DictionaryEncodable(["refresh_token": refreshToken]))
        let (data, http) = try await transport.send(req)
        guard (200...299).contains(http.statusCode) else {
            throw RemoteError.httpError(status: http.statusCode, data: data)
        }
        return try decoder.decode(TokenResponse.self, from: data)
    }

    enum RemoteError: Error {
        case httpError(status: Int, data: Data?)
    }
}
