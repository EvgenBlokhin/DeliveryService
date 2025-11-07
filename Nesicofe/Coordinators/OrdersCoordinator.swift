//
//  OrdersCoordinator.swift
//  Nesicofe
//
//  Created by dev on 27/10/2025.
//
import UIKit

final class OrdersCoordinator {
    let navigationController: UINavigationController
    private let ordersService: OrdersService
    private let storage: SimpleStorage
    private let webSocket: WebSocketService
    

    init(nav: UINavigationController, orders: OrdersService, storage: SimpleStorage, webSocket: WebSocketService) {
        self.navigationController = nav
        self.ordersService = orders
        self.storage = storage
        self.webSocket = webSocket
    }

    @MainActor func start() {
        let vm = OrdersViewModel(ordersService: ordersService, storage: storage)
        let vc = OrdersViewController(viewModel: vm)
        navigationController.setViewControllers([vc], animated: false)
    }
}
