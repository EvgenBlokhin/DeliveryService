//
//  ChatService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

import Foundation

actor ChatService {
    // MARK: - зависимости
    private let wsService: WebSocketService
    private let bufferStorage: BufferStorage
    private let coreData: CoreDataStorage?            // опционально, для allKeys
    private let outgoingBuffer: OutgoingBuffer<ChatMessage>

    // Continuation entry (идентифицируем по UUID)
    private struct ContinuationEntry {
        let id: UUID
        let continuation: AsyncStream<ChatEvent>.Continuation
    }
    // continuations keyed by storageKey (chat_messages::orderId)
    private var continuations: [String: [ContinuationEntry]] = [:]

    // JSON coders
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - init
    init(wsService: WebSocketService,
         bufferStorage: BufferStorage,
         coreData: CoreDataStorage? = nil,
         outgoingBufferStorageKey: String = "chat_outgoing_buffer") {
        self.wsService = wsService
        self.bufferStorage = bufferStorage
        self.coreData = coreData

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        self.outgoingBuffer = OutgoingBuffer<ChatMessage>(storage: bufferStorage, storageKey: outgoingBufferStorageKey)

        // Подписываемся на входящие сообщения из WS.
        // WebSocketService гарантирует вызов хендлера при получении ChatMessage.
        self.wsService.setIncomingChatHandler { [weak self] msg in
            // вызываем actor метод через Task
            Task { await self?.handleIncomingSocketMessage(msg) }
        }

        // Восстановление исходящего буфера из persistence (если есть)
        self.outgoingBuffer.restoreFromDisk()
    }

    // MARK: - Storage key helper
    private func storageKey(forOrderId orderId: String) -> String { "chat_messages::\(orderId)" }

    // MARK: - Fetch
    /// Возвращает все локально сохранённые сообщения для orderId (sorted asc)
    func fetchMessages(orderId: String) -> [ChatMessage] {
        let key = storageKey(forOrderId: orderId)
        do {
            if let arr: [ChatMessage] = try bufferStorage.load([ChatMessage].self, forKey: key) {
                return arr.sorted(by: { $0.timestamp < $1.timestamp })
            }
            return []
        } catch {
            print("ChatService.fetchMessages: load error:", error)
            return []
        }
    }

    // MARK: - Streams
    /// Возвращаем AsyncStream<ChatEvent>. При подписке шлём snapshot, а далее только инкрементальные newMessage.
    func messagesStream(orderId: String) -> AsyncStream<ChatEvent> {
        let key = storageKey(forOrderId: orderId)

        return AsyncStream<ChatEvent>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            // snapshot + регистрация continuation должна быть выполнена в actor-контексте,
            // поэтому используем Task { await ... } ниже.
            Task { [weak self] in
                guard let self = self else { return }
                // 1) шлём snapshot
                let snapshot = await self.fetchMessages(orderId: orderId)
                continuation.yield(.snapshot(snapshot))

                // 2) регистрируем continuation в actor
                let entry = ContinuationEntry(id: UUID(), continuation: continuation)
                await self.addContinuation(entry, forKey: key)

                // 3) onTermination -> удаляем
                continuation.onTermination = { @Sendable _ in
                    Task { await self.removeContinuation(entry.id, forKey: key) }
                }
            }
        }
    }

    // Добавить continuation (actor-isolated)
    private func addContinuation(_ entry: ContinuationEntry, forKey key: String) {
        if continuations[key] == nil { continuations[key] = [] }
        continuations[key]?.append(entry)
    }

    // Удалить continuation по id (actor-isolated)
    private func removeContinuation(_ id: UUID, forKey key: String) {
        if var list = continuations[key] {
            list.removeAll { $0.id == id }
            continuations[key] = list.isEmpty ? nil : list
        }
    }

    // Пуш инкрементального события newMessage
    private func pushNewMessageEvent(_ msg: ChatMessage) {
        let key = storageKey(forOrderId: msg.orderId)
        guard let list = continuations[key] else { return }
        for entry in list {
            entry.continuation.yield(.newMessage(msg))
        }
    }

    // MARK: - Send API (основная реализация)
    /// Создаёт локальное сообщение (local:id, idempotencyKey), сохраняет, пушит в стрим,
    /// помещает в outgoing buffer и пытается flush если есть подключение.
    func sendMessage(orderId: String, fromUserId: String, text: String) async {
        // 1) подготовить локальное сообщение
        let idempotency = UUID().uuidString
        let localId = "local:\(UUID().uuidString)"
        let msg = ChatMessage(
            id: localId,
            idempotencyKey: idempotency,
            orderId: orderId,
            fromUserId: fromUserId,
            text: text,
            timestamp: Date()
        )

        // 2) persist & enqueue
        await persistLocalAndQueueOutgoing(msg)

        // 3) попытаться flush сразу, если есть подключение
        let info = wsService.currentConnectionInfo()
        if info.isConnected, let task = info.task {
            outgoingBuffer.flush(using: task, encoder: encoder) { result in
                if case .failure(let err) = result {
                    print("ChatService.sendMessage: outgoing flush failed:", err)
                    // оставляем в буфере — повтор при reconnect
                }
            }
        }
        // иначе — ничего: OutgoingBuffer сохранит и flush произойдёт при reconnect
    }

    /// Сохранить локально (с дедупликацией) и положить в OutgoingBuffer
    private func persistLocalAndQueueOutgoing(_ msg: ChatMessage) async {
        let key = storageKey(forOrderId: msg.orderId)

        // загрузить существующие сообщения
        var arr: [ChatMessage] = []
        do {
            if let existing: [ChatMessage] = try bufferStorage.load([ChatMessage].self, forKey: key) {
                arr = existing
            }
        } catch {
            print("persistLocalAndQueueOutgoing: load error", error)
        }

        // дедупликация: сначала по idempotencyKey, затем по id
        var alreadyExists = false
        if let idem = msg.idempotencyKey {
            if arr.contains(where: { $0.idempotencyKey == idem }) {
                alreadyExists = true
            }
        }
        if !alreadyExists && arr.contains(where: { $0.id == msg.id }) {
            alreadyExists = true
        }

        if !alreadyExists {
            arr.append(msg)
            arr.sort { $0.timestamp < $1.timestamp }
            do {
                try bufferStorage.save(arr, forKey: key)
            } catch {
                print("persistLocalAndQueueOutgoing: save error", error)
            }

            // пушим инкрементальное событие — UI увидит оптимистично отправленное сообщение
            pushNewMessageEvent(msg)
        } else {
            // уже есть — пропускаем
        }

        // кладём в OutgoingBuffer (вне зависимости от успеха сохранения)
        outgoingBuffer.enqueue(msg)
    }

    // MARK: - Flush helper (опционально)
    func flushOutgoing(using task: URLSessionWebSocketTask, completion: ((Result<Void, Error>) -> Void)? = nil) {
        outgoingBuffer.flush(using: task, encoder: encoder, completion: completion)
    }

    // MARK: - Incoming WS handling
    /// Обработка входящего сообщения от сервера.
    /// Сначала пробуем сопоставить по idempotencyKey (заменить локальный черновик),
    /// затем по server id, иначе добавляем как новое.
    func handleIncomingSocketMessage(_ msg: ChatMessage) async {
        let key = storageKey(forOrderId: msg.orderId)

        var arr: [ChatMessage] = []
        do {
            if let existing: [ChatMessage] = try bufferStorage.load([ChatMessage].self, forKey: key) {
                arr = existing
            }
        } catch {
            print("handleIncomingSocketMessage: load failed:", error)
        }

        // 1) match by idempotencyKey (preferred) — заменяем локальный draft
        if let idem = msg.idempotencyKey, let idx = arr.firstIndex(where: { $0.idempotencyKey == idem }) {
            // заменяем локальный черновик на серверное сообщение
            arr[idx] = msg
            do { try bufferStorage.save(arr, forKey: key) } catch { print("handleIncomingSocketMessage: save failed:", error) }
            pushNewMessageEvent(msg)
            return
        }

        // 2) match by server id
        if let idx = arr.firstIndex(where: { $0.id == msg.id }) {
            arr[idx] = msg
            do { try bufferStorage.save(arr, forKey: key) } catch { print("handleIncomingSocketMessage: save failed:", error) }
            pushNewMessageEvent(msg)
            return
        }

        // 3) otherwise — новое входящее
        arr.append(msg)
        arr.sort { $0.timestamp < $1.timestamp }
        do { try bufferStorage.save(arr, forKey: key) } catch { print("handleIncomingSocketMessage: save failed:", error) }
        pushNewMessageEvent(msg)
    }

    // MARK: - Utilities
    /// Загрузить все чаты (если доступен coreData)
    func loadAllChats() -> [String: [ChatMessage]] {
        guard let core = coreData else { return [:] }
        do {
            let keys = try core.allKeys()
            var out: [String: [ChatMessage]] = [:]
            for k in keys where k.hasPrefix("chat_messages::") {
                let orderId = String(k.dropFirst("chat_messages::".count))
                if let arr: [ChatMessage] = try? bufferStorage.load([ChatMessage].self, forKey: k) {
                    out[orderId] = arr.sorted(by: { $0.timestamp < $1.timestamp })
                } else {
                    out[orderId] = []
                }
            }
            return out
        } catch {
            print("ChatService.loadAllChats error:", error)
            return [:]
        }
    }
}
