//
//  ChatViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []

    private let orderId: Int
    private let chatService: ChatService

    init(orderId: Int, chatService: ChatService) {
        self.orderId = orderId
        self.chatService = chatService
        
//        chatService.onMessage { [weak self] oid, msg in
//            guard oid == orderId else { return }
//            Task { [weak self] in
//                self?.messages.append(msg)
//                SimpleStorage.shared.save(self?.messages ?? [], key: "chat_\(orderId)")
//            }
//        }
        // Load old messages
        if let old: [ChatMessage] = SimpleStorage.shared.load([ChatMessage].self, key: "chat_\(orderId)") {
            self.messages = old
        }
    }

    func send(text: String, fromUserId: String) {
        let msg = ChatMessage(
            id: UUID().uuidString,
            orderId: orderId,
            fromUserId: fromUserId,
            text: text,
            timestamp: Date()
        )
        
        //chatService.sendChatMessage(message: messages)
        messages.append(msg)
        SimpleStorage.shared.save(messages, key: "chat_\(orderId)")
    }
}
