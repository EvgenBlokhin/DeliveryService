//
//  KeychainError.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case itemNotFound
    case failedToConvertToData
    case failedToConvertFromData
    case encodingFailed(Error)
    case decodingFailed(Error)
    case duplicateItem
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let s): return "Keychain unexpected status: \(s)"
        case .itemNotFound: return "Keychain item not found"
        case .failedToConvertToData: return "Failed to convert value to Data"
        case .failedToConvertFromData: return "Failed to convert Data to value"
        case .encodingFailed(let e): return "Encoding failed: \(e.localizedDescription)"
        case .decodingFailed(let e): return "Decoding failed: \(e.localizedDescription)"
        case .duplicateItem: return "Item already exists in Keychain"
        case .unknown(let e): return "Unknown Keychain error: \(e.localizedDescription)"
        }
    }
}
