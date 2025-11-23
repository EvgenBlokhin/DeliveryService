//
//  CartCoordinator.swift
//  Nesicofe
//
//  Created by dev on 27/10/2025.
//
import UIKit
final class CartCoordinator {
    var navigationController: UINavigationController
    private let authService: AuthService
    private let cartService: CartService
    private let chatService: ChatService
    private let orderService: OrderService
    private let webSocketService: WebSocketService
    private weak var addressProvider: UserAddressProviding?
    
    init(nav: UINavigationController, auth: AuthService, cart: CartService, chat: ChatService, orders: OrderService, addressProvider: UserAddressProviding, webSocket: WebSocketService) {
        self.navigationController = nav
        self.authService = auth
        self.cartService = cart
        self.orderService = orders
        self.addressProvider = addressProvider
        self.chatService = chat
        self.webSocketService = webSocket
    }
    
    func start() {
        guard let addressProvider = addressProvider else { return }
        let vm = CartViewModel(cart: cartService, orders: orderService, auth: authService, address: addressProvider)
        let vc = CartViewController(viewModel: vm)
        
        //vm.onUpdated = { [weak vc] in vc?.reload() }
        vm.onNeedAddress = { [weak vc] in vc?.askAddress() }
        vm.onCourierIsCustomerRequired = { [weak vc] in vc?.alert("Доступно только покупателю", "Войдите в профиль покупателя") }
        vm.onOrderCreated = { [weak self] order in
            guard let self else { return }
            Task {
                try await self.orderService.createOrder(order: order)
            }
            vm.onError = { [weak vc] msg in vc?.alert("Упс", msg) }
            navigationController.setViewControllers([vc], animated: false)
        }
    }
}
