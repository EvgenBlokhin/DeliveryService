//
//  MachineDetailsCoordinator.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class MachineDetailsCoordinator {
    private let nav: UINavigationController
    private let cart: CartService
    private weak var tabBarController: UITabBarController?

    init(navigation: UINavigationController, cart: CartService, tabBarController: UITabBarController) {
        self.nav = navigation
        self.cart = cart
        self.tabBarController = tabBarController
    }

    func start(with machine: MachineModel) {
        let viewModel = MachineDetailsViewModel(machine: machine, cart: cart)
        let viewController = MachineDetailsViewController(viewModel: viewModel)

        // Навигация в корзину через замыкание VM
        viewModel.onOpenCart = { [weak self] in
            self?.tabBarController?.selectedIndex = 2 // корзина в табе №2
        }

        nav.pushViewController(viewController, animated: true)
    }
}
