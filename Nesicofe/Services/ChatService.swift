//
//  ChatService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

final class ChatService {
    private let wsClient: WebSocketService
    init(wsClient: WebSocketService) { self.wsClient = wsClient }

    func connect(chatId: String) {
        wsClient.connect(chatId: chatId)
    }

    func disconnect() {
        wsClient.disconnect()
    }

//    func sendChatMessage(message: ChatMessage) {
//        // Здесь можно добавить клиентское шифрование (E2E) при необходимости
//        wsClient.send(message: message)
//    }
//
//    func onMessage(_ handler: @escaping (ChatMessage) -> Void) {
//        wsClient.onMessage = handler
//    }
}
