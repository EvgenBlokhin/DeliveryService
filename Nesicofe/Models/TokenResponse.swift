//
//  TokenResponse.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Date?
    let token_type: String?
    let user: UserProfile
}
