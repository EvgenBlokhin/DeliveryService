//
//  UserProfile.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

enum UserRole: String, Codable, Equatable { case customer, courier }

struct User: Codable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let role: UserRole
    let rating: Double?
}
