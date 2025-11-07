//
//  KeychainHelper.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

public protocol KeychainProtocol {
    // String API
    //func save(_ value: String, for key: String) throws
    //func readString(for key: String) throws -> String?
    // Data API
    func save(_ data: Data, for key: String) throws
    func readData(for key: String) throws -> Data?
    // Codable API
    func save<T: Codable>(_ value: T, for key: String) throws
    func readCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T?
    // Delete
    func delete(_ key: String) throws
    // Remove all items for service (use carefully)
    func clearAllSavedItems() throws
    // Convenience/back-compat helpers
    //func saveStringCompat(_ value: String, account: String) throws
    //func readStringCompat(account: String) throws -> String?
}

public final class KeychainHelper: KeychainProtocol {

    public static let shared = KeychainHelper()

    /// JSON encoder/decoder for Codable
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Serial queue для thread-safety
    private let queue = DispatchQueue(label: "com.coffeedelivery.keychain.queue")

    /// Accessibility policy (по умолчанию безопасный вариант)
    private let accessibility: CFString

    /// Optional access group (для sharing между приложениями/extensions) — nil по умолчанию
    private let accessGroup: String?

    /// Service (scope) — по умолчанию bundle identifier
    private let service: String

    /// Инициализатор: при необходимости можно создать кастомный экземпляр (для тестов)
    public init(service: String = Bundle.main.bundleIdentifier ?? "com.coffeedelivery.app",
                accessGroup: String? = nil,
                accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    //  Public API (String)

//    /// Сохранить строку в Keychain (UTF-8)
//    public func save(_ value: String, for key: String) throws {
//        guard let data = value.data(using: .utf8) else {
//            throw KeychainError.failedToConvertToData
//        }
//        try save(data, for: key)
//    }

//    /// Прочитать строку из Keychain
//    public func readString(for key: String) throws -> String? {
//        guard let data = try readData(for: key) else { return nil }
//        guard let s = String(data: data, encoding: .utf8) else {
//            throw KeychainError.failedToConvertFromData
//        }
//        return s
//    }

    // Public API (Data)

    /// Сохранить Data в Keychain
    public func save(_ data: Data, for key: String) throws {
        // Работа с SecItem требует словаря запроса. Используем стратегию: пытаемся добавить, при duplicateItem — обновляем.
        let query = baseQuery(for: key)

        // Попробуем добавить
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility
        if let ag = accessGroup {
            addQuery[kSecAttrAccessGroup as String] = ag
        }

        var status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            return
        } else if status == errSecDuplicateItem {
            // Обновим существующий
            let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
            let updateQuery = baseQuery(for: key)
            status = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
            return
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Прочитать Data из Keychain
    public func readData(for key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data else {
                throw KeychainError.failedToConvertFromData
            }
            return data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    //  Public API (Codable)

    /// Сохранить Codable объект (JSON) в Keychain
    public func save<T: Codable>(_ value: T, for key: String) throws {
        do {
            let data = try encoder.encode(value)
            try save(data, for: key)
        } catch let err as KeychainError {
            throw err
        } catch {
            throw KeychainError.encodingFailed(error)
        }
    }

    /// Прочитать Codable объект из Keychain. Возвращает nil если нет значения.
    public func readCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T? {
        do {
            guard let data = try readData(for: key) else { return nil }
            let obj = try decoder.decode(T.self, from: data)
            return obj
        } catch let err as KeychainError {
            throw err
        } catch {
            throw KeychainError.decodingFailed(error)
        }
    }

    // MARK: - Delete / Clear

    /// Удалить элемент по ключу
    public func delete(_ key: String) throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Очистить все элементы для service (использовать осторожно)
    public func clearAllSavedItems() throws {
        var query: [String: Any] = [:]
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service
        if let ag = accessGroup {
            query[kSecAttrAccessGroup as String] = ag
        }
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    //  Convenience / Backwards-compat helpers

    /// Для обратной совместимости с кодом, который использовал `read(account:)`
    /// Прим.: старые места в коде могут вызывать KeychainHelper.shared.read(account: "accessToken")
    /// — ниже реализован аналогичнный интерфейс.
//    public func readStringCompat(account: String) throws -> String? {
//        return try readString(for: account)
//    }
//
//    /// Сохранить строку с именем поля account (back-compat)
//    public func saveStringCompat(_ value: String, account: String) throws {
//        try save(value, for: account)
//    }

    // Helpers

    /// Формирует базовый query словарь для заданного ключа (account)
    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [:]
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = key
        return query
    }
}

//Optional convenience methods for TokenResponse (app-specific)

// Если в проекте используется модель TokenResponse, удобно иметь обёртки:
public extension KeychainHelper {
    private static var tokenKey: String { "token_response" }

    /// Сохранить TokenResponse (удобная обёртка)
    private func saveTokenResponse(_ token: TokenResponse) throws {
        try save(token, for: KeychainHelper.tokenKey)
    }

    /// Прочитать TokenResponse
    private func readTokenResponse() throws -> TokenResponse? {
        return try readCodable(TokenResponse.self, for: KeychainHelper.tokenKey)
    }

    /// Удалить TokenResponse
    func deleteTokenResponse() throws {
        try delete(KeychainHelper.tokenKey)
    }
}
