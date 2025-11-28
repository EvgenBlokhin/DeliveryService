//
//  ChatEvent.swift
//  Nesicofe
//
//  Created by dev on 17/11/2025.
//

enum ChatEvent {
    /// полный снэпшот сообщений при подписке
    case snapshot([ChatMessage])
    /// пришло новое сообщение
    case newMessage(ChatMessage)
}
