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
    private let mapService: MapService
    private let cartService: CartService
    private let ordersService: OrderService
    private let chatService: ChatService
    private let locationService: UserLocationService
    private let webSocketSerrvice: WebSocketService

    // retain Details
    private var detailsCoord: MachineDetailsCoordinator?

    init(navigation: UINavigationController, tabBar: UITabBarController, map: MapService, cart: CartService, chat: ChatService, orders: OrderService, location: UserLocationService, webSocket: WebSocketService) {
        self.navigationController = navigation
        self.mapService = map
        self.cartService = cart
        self.chatService = chat
        self.ordersService = orders
        self.locationService = location
        self.tabBarController = tabBar
        self.webSocketSerrvice = webSocket
        //NotificationCenter.default.addObserver(self, selector: #selector(courierAssigned(_:)), name: .orderCourierAssigned, object: nil)
    }

    func start() {
        let viewModel = MapViewModel(service: mapService, location: locationService)
        let viewController = MapViewController(viewModel: viewModel)
        viewModel.onOpenMachine = { [weak self] machineId in
            guard let self else { return }
            self.openMachine(machineId)
        }
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
