//
//  StoredToken.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

struct StoredToken: Codable {
    let tokenResponse: TokenResponse
    let expiryDate: Date?
}
