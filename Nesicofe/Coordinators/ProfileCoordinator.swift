//
//  ProfileCoordinator.swift
//  Nesicofe
//
//  Created by dev on 27/10/2025.
//
import UIKit
@MainActor
final class ProfileCoordinator: Coordinator {
    let navigationController: UINavigationController
    private let authService: AuthService
    

    init(nav: UINavigationController, auth: AuthService) {
        self.navigationController = nav
        self.authService = auth
        
    }

    func start() {
        if authService.currentUser == nil {
            showAuth()
        } else {
            showProfile()
        }
    }

    private func showAuth() {
        let vm = AuthorizationViewModel(auth: authService)
        let vc = AuthorizationViewController(viewModel: vm)

        vm.onRegisterSuccess = { [weak self] user in
            self?.showProfile()
        }
        vm.onLoginSuccess = { [weak self] user in
            self?.showProfile()
        }
        vm.onError = { [weak vc] msg in vc?.alert("Упс...", msg) }

        navigationController.setViewControllers([vc], animated: true)
    }

    private func showProfile() {
        let vm = ProfileViewModel(auth: authService)
        let vc = ProfileViewController(viewModel: vm)
        vm.onLogout = { [weak self] in
            self?.showAuth()
        }
        navigationController.setViewControllers([vc], animated: true) // заменяем стек на один экран
    }
   
}

