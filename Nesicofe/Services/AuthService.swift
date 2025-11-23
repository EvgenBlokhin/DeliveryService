//
//  AuthService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation


final class AuthService: ObservableObject {
    //static let shared = AuthService(remote: AuthRemoteDataSourceProtocol.self as! AuthRemoteDataSourceProtocol, keychain: KeychainHelper.shared)

    //@Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUser: User? = nil

    private let remote: AuthRemoteDataSourceProtocol
    private let keychain: KeychainHelper
    private let tokenStorageKey = "token_response_stored" // use StoredToken
    private let refreshCoordinator = RefreshCoordinator()
    private(set) var inMemoryAccessToken: String? = nil
    private(set) var inMemoryExpiry: Date? = nil

    var isAuthenticated: ((Bool) -> Void)?
    var onLogout: (() -> Void)?

    init(remote: AuthRemoteDataSourceProtocol, keychain: KeychainHelper = .shared) {
        self.remote = remote
        self.keychain = keychain
        Task { await loadStored() }
    }

    // LOAD stored StoredToken
    private func loadStored() async {
        do {
            if let stored: StoredToken = try keychain.readCodable(StoredToken.self, for: tokenStorageKey) {
                self.inMemoryAccessToken = stored.tokenResponse.access_token
                self.inMemoryExpiry = stored.expiryDate
                self.currentUser = stored.tokenResponse.user
                self.isAuthenticated?(!(stored.tokenResponse.access_token.isEmpty))
            } else {
                self.inMemoryAccessToken = nil
                self.inMemoryExpiry = nil
                self.currentUser = nil
                self.isAuthenticated?(false)
            }
        } catch {
            print("AuthService.loadStored error:", error)
        }
    }

    // save tokenResponse wrapped into StoredToken (computes expiryDate)
    private func saveTokenResponse(_ token: TokenResponse) async throws {
        let expiryDate: Date?
        if let expires = token.expires_in {
            let timeInterval: TimeInterval = expires.timeIntervalSinceReferenceDate
            expiryDate = Date().addingTimeInterval(timeInterval)
        } else {
            expiryDate = nil
        }
        let stored = StoredToken(tokenResponse: token, expiryDate: expiryDate)
        try keychain.save(stored, for: tokenStorageKey)
        // update memory
        inMemoryAccessToken = token.access_token
        inMemoryExpiry = expiryDate
        currentUser = token.user
        isAuthenticated?(!(token.access_token.isEmpty))
    }

    // sync getter for token (async)
    func getAccessToken() async -> String? {
        return inMemoryAccessToken
    }

    func getAccessTokenExpiry() async -> Date? {
        return inMemoryExpiry
    }

    // LOGIN
    func login(email: String, password: String) async throws -> User {
            let token = try await remote.login(email: email, password: password)
            try await saveTokenResponse(token)
            return token.user
    }
    
    func register(name: String, phone: String, email: String, password: String, role: String) async throws -> User {
        let token = try await remote.register(name: name, phone: phone, email: email, password: password, role: role)
        try await saveTokenResponse(token)
        return token.user
    }

    // REFRESH (should be called via RefreshCoordinator to avoid races)
    func refreshToken() async throws {
        guard let refresh = (try? keychain.readCodable(StoredToken.self, for: tokenStorageKey))?.tokenResponse.refresh_token else {
            throw AuthError.missingRefreshToken
        }
        let token = try await remote.refreshToken(refreshToken: refresh)
        try await saveTokenResponse(token)
    }

    // expose a safe refresh method that uses coordinator
    func refreshTokenSingleflight() async throws {
        try await refreshCoordinator.perform {
            try await self.refreshToken()
        }
    }

    // logout
    func logout() async {
        try? keychain.delete(tokenStorageKey)
        inMemoryAccessToken = nil
        inMemoryExpiry = nil
        currentUser = nil
        isAuthenticated?(false)
    }
   

    // helpers
    func getStoredAuth() -> TokenResponse? {
        return (try? keychain.readCodable(StoredToken.self, for: tokenStorageKey))?.tokenResponse
    }

    enum AuthError: Error {
        case missingRefreshToken
    }
}
extension AuthService {
    /// Проверяет, действителен ли текущий accessToken
    func isAccessTokenValid(threshold: TimeInterval = 60) async -> Bool {
        guard let expiry = await getAccessTokenExpiry() else {
            return false
        }
        // Если до истечения токена осталось меньше threshold секунд — считаем его просроченным
        return Date() < expiry.addingTimeInterval(-threshold)
    }
    
    /// Обновляет access token при необходимости.
        /// Возвращает true, если токен действителен (после возможного обновления).
    func refreshIfNeeded() async throws -> Bool {
            // Проверим валидность accessToken
            if await isAccessTokenValid() {
                // всё хорошо — токен действителен, ничего не делаем
                return true
            }

            // Попробуем выполнить refresh
            do {
                try await refreshTokenSingleflight()
                return true
            } catch {
                print("AuthService.refreshIfNeeded() error: \(error)")
                return false
            }
        }
}
