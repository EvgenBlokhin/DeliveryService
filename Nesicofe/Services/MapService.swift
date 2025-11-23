//
//  MapService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

final class MapService {

    private let client: NetworkClient
    private var webSocket: WebSocketService?
    
    init(client: NetworkClient) {
        self.client = client
    }
    
    func setWebSocket(_ socket: WebSocketService) {
        self.webSocket = socket
    }

    func fetchMachines() async throws -> [MachineModel] {
        return try await client.request(path: "map/points", method: "GET", body: nil, requiresAuth: false)
    }
    
    func fetchCourier() async throws -> [CourierModel] {
        return try await client.request(path: "map/courier", method: "GET", body: nil, requiresAuth: false)
    }


}
