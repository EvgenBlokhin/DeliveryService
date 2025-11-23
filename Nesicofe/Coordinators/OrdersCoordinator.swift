//
//  OrdersCoordinator.swift
//  Nesicofe
//
//  Created by dev on 27/10/2025.
//
import UIKit

final class OrdersCoordinator: Coordinator {
    let navigationController: UINavigationController
    private let ordersService: OrderService
    private let storage: CoreDataStorage
    private let webSocket: WebSocketService
    private let chatService: ChatService
    

    init(nav: UINavigationController, orders: OrderService, storage: CoreDataStorage, webSocket: WebSocketService, chatService: ChatService) {
        self.navigationController = nav
        self.ordersService = orders
        self.storage = storage
        self.webSocket = webSocket
        self.chatService = chatService
    }

    @MainActor func start() {
        let vm = OrderViewModel(orderService: ordersService)
        let vc = OrdersViewController(viewModel: vm)
        navigationController.setViewControllers([vc], animated: false)
    }
}
