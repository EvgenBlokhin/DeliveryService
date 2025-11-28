//
//  ChatMessage.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

struct ChatMessage: Codable, Equatable, Identifiable {
    var id: String                 // local:"local:UUID()" или server id
    var idempotencyKey: String?
    var orderId: String
    var fromUserId: String
    var text: String
    var timestamp: Date

    init(id: String = UUID().uuidString,
                idempotencyKey: String? = nil,
                orderId: String,
                fromUserId: String,
                text: String,
                timestamp: Date = Date()) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.orderId = orderId
        self.fromUserId = fromUserId
        self.text = text
        self.timestamp = timestamp
    }
}
