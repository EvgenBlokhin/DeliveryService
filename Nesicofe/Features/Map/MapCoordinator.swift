//
//  MapCoordinator.swift
//  Nesicofe
//
//  Created by dev on 27/08/2025.
//

import UIKit

final class MapCoordinator: Coordinator {
    let navigationController: UINavigationController
    let tabBarController: UITabBarController
    private let machineService: MockService
    private let cartService: CartService
    private let ordersService: OrdersService
    private let authService: AuthServiceProtocol
    private let locationService: LocationService

    // retain Details
    private var detailsCoord: MachineDetailsCoordinator?

    init(navigation: UINavigationController, tabBar: UITabBarController, service: MockService, cart: CartService, orders: OrdersService, auth: AuthServiceProtocol, location: LocationService) {
        self.navigationController = navigation
        self.machineService = service
        self.cartService = cart
        self.ordersService = orders
        self.authService = auth
        self.locationService = location
        self.tabBarController = tabBar
        //NotificationCenter.default.addObserver(self, selector: #selector(courierAssigned(_:)), name: .orderCourierAssigned, object: nil)
    }

    func start() {
        let viewModel = MapViewModel(machines: machineService, location: locationService)
        let viewController = MapViewController(viewModel: viewModel)
        viewModel.onOpenMachine = { [weak self] machineId in
            guard let self, let machine = self.machineService.machine(id: machineId) else { return }
            self.openMachine(machine)
        }
        viewModel.onOpenChat = { [weak self] orderId in
            guard let self else { return }
            let chatCoord = ChatCoordinator(nav: self.navigationController, auth: self.authService)
            chatCoord.openChat(orderId: orderId)
        }
        navigationController.setViewControllers([viewController], animated: false)
    }


    private func openMachine(_ machine: MachineModel) {
        let coord = MachineDetailsCoordinator(navigation: navigationController, cart: cartService, tabBarController: tabBarController)
        coord.start(with: machine)
        self.detailsCoord = coord
    }

//    @objc private func courierAssigned(_ note: Notification) {
//        guard note.object is OrderModel else { return }
//        // Простая имитация координаты курьера — рядом с заказом
//        let offset = CLLocationCoordinate2D(latitude: 0.0009, longitude: 0.0009)
//        let courierCoord = CLLocationCoordinate2D(latitude: locationService.currentCenter.latitude + offset.latitude,
//                                                  longitude: locationService.currentCenter.longitude + offset.longitude)
//        (navigationController.viewControllers.first as? MapViewController)?.showCourier(at: courierCoord)
//    }
}
