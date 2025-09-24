//
//  AppCoordinator.swift
//  Nesicofe
//
//  Created by dev on 25/08/2025.
//

import UIKit

protocol CoordinatorProtocol: AnyObject {
    var navigationController: UINavigationController { get set }
    func start()
}
final class AppCoordinator: CoordinatorProtocol {
    
    private let window: UIWindow
    var navigationController: UINavigationController
    private let locationService = LocationService.shared
    
    init(window: UIWindow, navigationController: UINavigationController, locationService: LocationService) {
        self.window = window
        self.navigationController = navigationController
    }
    
    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        showInitalScreen()
    }
    private func showInitalScreen() {
        if locationService.handleAuthorizationStatus() {
            showMapViewController()
        } else {
            showAddressSearchViewController()
        }
    }
    private func showAddressSearchViewController() {
            let mainVC = AddressSearchViewController()
        navigationController.setViewControllers([mainVC], animated: true)
        }
    private func showMapViewController() {
        let mainVC = MapViewController(coordinator: self)
        navigationController.setViewControllers([mainVC], animated: true)
        }
    
    
    
}
