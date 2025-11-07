//
//  OrdersService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

final class OrdersService {
    private let client: NetworkClient
    init(client: NetworkClient) { self.client = client }

    func createOrder(fromAddress: String, toAddress: String, items: [CartItem], price: Double?, contact: String) async throws -> OrderModel {
        var body: [String: Any] = ["from": fromAddress, "to": toAddress, "contact": contact, "items": items]
        if let price = price { body["price"] = price }
        return try await client.request(path: "orders", method: "POST", body: DictionaryEncodable(body), requiresAuth: true)
    }

    func getMyOrders() async throws -> [OrderModel] {
        return try await client.request(path: "orders/my", method: "GET", body: nil, requiresAuth: true)
    }

    func acceptOrder(orderId: String) async throws -> OrderModel {
        return try await client.request(path: "orders/\(orderId)/accept", method: "POST", body: nil, requiresAuth: true)
    }
}
