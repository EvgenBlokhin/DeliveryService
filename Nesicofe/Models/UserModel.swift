//
//  UserModel.swift
//  Nesicofe
//
//  Created by dev on 24/09/2025.
//

enum UserRole: String, Codable, Equatable { case customer, courier }

struct UserModel: Codable, Equatable {
    let id: String
    var name: String
    var phone: String
    var role: UserRole
    var rating: Double
}
