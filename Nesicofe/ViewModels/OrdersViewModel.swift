//
//  OrdersViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

class OrdersViewModel: ObservableObject {
    @Published var orders: [OrderModel] = []

    private let ordersService: OrdersService
    private let storage: SimpleStorage

    init(ordersService: OrdersService, storage: SimpleStorage) {
        self.ordersService = ordersService
        self.storage = storage
    }

    func loadOrders() async {
        if let saved: [OrderModel] = storage.load([OrderModel].self, key: "orders_history") {
            self.orders = saved
        }
        do {
            let fresh = try await ordersService.getMyOrders()
            self.orders = fresh
            storage.save(fresh, key: "orders_history")
        } catch {
            print("Ошибка getMyOrders:", error)
        }
    }
}
