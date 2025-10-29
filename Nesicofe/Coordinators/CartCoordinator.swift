//
//  CartCoordinator.swift
//  Nesicofe
//
//  Created by dev on 27/10/2025.
//
import UIKit
final class CartCoordinator {
    let navigationController: UINavigationController
    private let authService: AuthService
    private let cartService: CartService
    private let chatService: ChatService
    private let ordersService: OrdersService
    private weak var addressProvider: AddressProviding?

    init(nav: UINavigationController, auth: AuthService, cart: CartService, chat: ChatService, orders: OrdersService, addressProvider: AddressProviding) {
        self.navigationController = nav
        self.authService = auth
        self.cartService = cart
        self.ordersService = orders
        self.addressProvider = addressProvider
        self.chatService = chat
    }

    func start() {
        guard let addressProvider = addressProvider else { return }
        let vm = CartViewModel(cart: cartService, orders: ordersService, auth: authService, address: addressProvider)
        let vc = CartViewController(viewModel: vm)

        //vm.onUpdated = { [weak vc] in vc?.reload() }
        vm.onNeedAddress = { [weak vc] in vc?.askAddress() }
        vm.onCourierIsCustomerRequired = { [weak vc] in vc?.alert("Доступно только покупателю", "Войдите в профиль покупателя") }
        vm.onOrderCreated = { [weak self] order in
            guard let self else { return }
            let chat = ChatCoordinator(nav: self.navigationController, service: self.chatService)
            DispatchQueue.main.async {
                chat.openChat(orderId: order.id)
            }
        }
        vm.onError = { [weak vc] msg in vc?.alert("Упс", msg) }
        navigationController.setViewControllers([vc], animated: false)
    }
}
