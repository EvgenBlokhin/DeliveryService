//
//  UserProfile.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

struct UserProfile: Codable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let role: String?// "buyer" | "courier"
    let rating: Double?
}
