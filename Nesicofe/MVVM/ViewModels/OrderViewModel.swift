//
//  OrdersViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

class OrderViewModel: ObservableObject {
    @Published private(set) var orders: [OrderModel] = []

    private let orderService: OrderService

    init(orderService: OrderService) {
        self.orderService = orderService
        Task { await self.loadOrders() }
        
        orderService.onOrderUpdate = { [weak self] order in
            guard let self = self else { return }
            self.applyOrderUpdate(order: order)
        }
    }
    private func applyOrderUpdate(order: OrderModel) {
        if let serverId = order.id, let orderId = orders.firstIndex(where: { $0.id == serverId }) {
            orders[orderId] = order
        } else {
            if let idem = order.idempotencyKey,
               let idx = orders.firstIndex(where: {$0.idempotencyKey == idem}) {
                orders[idx] = order
            } else { orders.append(order)}
        }
        orders.sort {$0.createdAt > $1.createdAt}
    }

    func loadOrders() async {
        do {
            let orders = try orderService.loadAllLocalOrders()
            self.orders = orders
        } catch {
            print("Ошибка получения всех ордеров:", error)
        }
    }
}
