//
//  OrderModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

enum OrderStatus: String, Codable {
    case created, searching, assigned, running, delivering, done, cancelled
}

struct OrderModel: Codable, Equatable {
    public var id: Int
    public var machineId: Int
    public var userId: String
    public var createdAt: Date
    public var status: OrderStatus
    public var address: String
    public var items: [CartItem]
    public var courierId: String?
}
