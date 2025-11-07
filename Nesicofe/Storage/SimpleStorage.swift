//
//  SimpleStorage.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

final class SimpleStorage {
    static let shared = SimpleStorage()
    private let defaults = UserDefaults.standard

    func save<T: Codable>(_ obj: T, key: String) {
        do {
            let d = try JSONEncoder().encode(obj)
            defaults.set(d, forKey: key)
        } catch {
            print("Storage save error [\(key)]:", error)
        }
    }

    func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Storage decode error [\(key)]:", error)
            return nil
        }
    }

    func remove(key: String) { defaults.removeObject(forKey: key) }
}
