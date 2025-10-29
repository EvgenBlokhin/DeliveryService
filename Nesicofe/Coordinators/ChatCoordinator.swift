//
//  ChatCoordinator.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit
final class ChatCoordinator {
    private let nav: UINavigationController
    private let service: ChatService

    init(nav: UINavigationController, service: ChatService) {
        self.nav = nav
        self.service = service
    }

    @MainActor func openChat(orderId: Int) {
        let vm = ChatViewModel(orderId: orderId, chatService: service)
        let vc = ChatViewController(viewModel: vm)
        nav.pushViewController(vc, animated: true)
    }
}
