//
//  ChatCoordinator.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit
final class ChatCoordinator {
    private let navigationController: UINavigationController
    private let service: ChatService
    private let webSocket: WebSocketService
    private let orderId: String
    private let userId: String

    init(navigationController: UINavigationController, service: ChatService, webSocket: WebSocketService, orderId: String, userId: String) {
        self.navigationController = navigationController
        self.service = service
        self.webSocket = webSocket
        self.orderId = orderId
        self.userId = userId
    }

    @MainActor func start(orderId: String) {
        let vm = ChatViewModel(chatService: service, orderId: orderId, currentUserId: userId)
        let vc = ChatViewController(viewModel: vm)
        
        navigationController.setViewControllers([vc], animated: false)
    }
}
