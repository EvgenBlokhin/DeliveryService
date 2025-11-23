//
//  OrderEntity.swift
//  Nesicofe
//
//  Created by dev on 06/11/2025.
//
import Foundation

struct OrderEntity: Codable, Hashable {
    var id: String?
    var idempotencyKey: String
    var userId: String
    var machineId: Int64
    var createdAt: Date
    var status: String
    var address: String
    var itemsData: Data
    var courier: Data?
    var attempts: Int16
    var needsSync: Bool
}
