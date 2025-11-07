//
//  WSEnvelope.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

struct WSEnvelope: Codable {
    public let type: WSMessageType
    public let orderId: Int?    // не всегда есть
    public let payload: Data?      // raw JSON payload (даёт гибкость)
    public let meta: [String: String]? // доп. поля, при необходимости

    public init(type: WSMessageType, orderId: Int? = nil, payload: Data? = nil, meta: [String: String]? = nil) {
        self.type = type
        self.orderId = orderId
        self.payload = payload
        self.meta = meta
    }
}

