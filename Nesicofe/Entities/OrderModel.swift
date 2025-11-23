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

struct OrderModel: Codable, Equatable, Identifiable {
    public var id: String?                 // serverOrderId — приходит с сервера (может быть nil до подтверждения)
    public var idempotencyKey: String?   // уникальный ключ для предотвращения дубликатов
    public var machineId: Int
    public var userId: String
    public var createdAt: Date
    public var status: OrderStatus
    public var address: String
    public var items: [CartItem]
    public var courier: [CourierModel]

    init(
        id: String? = nil,
        idempotencyKey: String? = nil,
        machineId: Int,
        userId: String,
        createdAt: Date = Date(),
        status: OrderStatus,
        address: String,
        items: [CartItem],
        courier: [CourierModel] = []
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.machineId = machineId
        self.userId = userId
        self.createdAt = createdAt
        self.status = status
        self.address = address
        self.items = items
        self.courier = courier
    }
}
