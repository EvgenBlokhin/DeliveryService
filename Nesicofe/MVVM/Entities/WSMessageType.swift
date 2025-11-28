//
//  WSMessageType.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

enum WSMessageType: String, Codable {
    case orderCreatedAck
    case orderAssigned
    case newOrderForCourier
    case orderCancelled
    case orderUpdated
    case courierAccepted
    case courierDeclined
    case orderDone
    case updateCourierLocation
    case chatMessage
    case heartbeat
}
