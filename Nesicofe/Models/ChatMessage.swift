//
//  ChatMessage.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    public let id: String
    public let orderId: Int
    public let fromUserId: String
    public let text: String
    public let timestamp: Date

    public init(id: String = UUID().uuidString,
                orderId: Int,
                fromUserId: String,
                text: String,
                timestamp: Date = Date()) {
        self.id = id
        self.orderId = orderId
        self.fromUserId = fromUserId
        self.text = text
        self.timestamp = timestamp
    }
}
