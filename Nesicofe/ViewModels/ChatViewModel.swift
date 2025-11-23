//
//  ChatViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    private let chatService: ChatService
    private let orderId: String
    private let currentUserId: String

    init(chatService: ChatService, orderId: String, currentUserId: String) {
        self.chatService = chatService
        self.orderId = orderId
        self.currentUserId = currentUserId
    }

    /// Вызывается UI (например, при нажатии кнопки отправить).
    func send(text: String) {
        Task {
            await chatService.sendMessage(orderId: orderId, fromUserId: currentUserId, text: text)
        }
    }

    // bind to stream (пример, как получать события от ChatService)
    func bindMessages() {
        Task { [weak self] in
            guard let self = self else { return }
            for await event in await chatService.messagesStream(orderId: orderId) {
                await MainActor.run {
                    switch event {
                    case .snapshot(let arr):
                        self.messages = arr
                    case .newMessage(let msg):
                        // замена по idempotencyKey / id либо добавление
                        if let idem = msg.idempotencyKey,
                           let idx = self.messages.firstIndex(where: { $0.idempotencyKey == idem }) {
                            self.messages[idx] = msg
                        } else if let idx = self.messages.firstIndex(where: { $0.id == msg.id }) {
                            self.messages[idx] = msg
                        } else {
                            self.messages.append(msg)
                        }
                        self.messages.sort { $0.timestamp < $1.timestamp }
                    }
                }
            }
        }
    }
}
