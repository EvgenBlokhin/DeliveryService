//
//  WebSocketService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation
import CoreData
import UIKit
import Combine

final class WebSocketService: @unchecked Sendable {
    
    private var authService: AuthService
    private var orderService: OrderService
    private var keyChain: KeychainHelper
    private var bufferStorage: BufferStorage
    private lazy var outgoingBufferManager: OutgoingBuffer<ChatMessage> = {
        return OutgoingBuffer<ChatMessage>(storage: self.bufferStorage)
    }()
    /// флаг чтобы не делать flush до restore
    private var isBufferRestored: Bool = false
   
    private let wsURLString: String = "wss://api.example.com/socket"
    private var wsURL: URL { URL(string: wsURLString)! }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var session: URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: cfg)
        return session
    }
    private var webSocketTask: URLSessionWebSocketTask?
    private var listeningTask: Task<Void, Never>?   // receive loop
    private var pingTask: Task<Void, Never>?        // ping loop
    /// Serial queue для защиты внутреннего состояния (thread-safety)
    private let queue = DispatchQueue(label: "com.coffeedelivery.websocket.queue")
    /// Внутренний булев флаг (читается/писается в queue)
    private var isConnectedInternal: Bool = false
    /// Для автопереподключения
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 8
    private let reconnectBaseDelay: TimeInterval = 1.0
    private let reconnectMaxDelay: TimeInterval = 60.0
    /// FIFO буфер для ChatMessage (если соединение отсутствует)
    private let persistBufferOnDisk: Bool = true // можно включить/выключить
    /// Автосохранённые параметры подключения
    /// Если нужно — сохраняем chatId / orderId чтобы service мог автоматически переподключаться
    private var currentChatId: String?
    private var currentOrderId: String?
    /// Callbacks (все вызываются на main thread)
    public var onOpen: (() -> Void)?
    public var onClose: ((Error?) -> Void)?
    
    @Published private(set) var courierLocation: [Coordinate] = []
    private var incomingChatHandler: ((ChatMessage) -> Void)?

    var onRequestForDelivery: ((OrderModel) -> Void)?
    var onOrderCancelled: ((OrderModel) -> Void)?
    var onOrderUpdated: ((OrderModel) -> Void)?
    
    var onCourierAccepted: ((OrderModel) -> Void)?
    var onCourierDeclined: ((OrderModel) -> Void)?


    init(authService: AuthService, orderService: OrderService,  keyChain: KeychainHelper, bufferStorage: BufferStorage) {
        
        self.authService = authService
        self.orderService = orderService
        self.keyChain = keyChain
        //self.coreData = coreData
        self.bufferStorage = bufferStorage
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        /// восстановление буфера при старте (если включено)
        if persistBufferOnDisk {
            restoreOutgoingBufferFromDisk()
        }
    }

    deinit {
        disconnect()
    }
    
#if DEBUG
fileprivate func log(_ items: Any...) { print("[AuthNet] ", items.map { "\($0)" }.joined(separator: " ")) }
#else
fileprivate func log(_ items: Any...) { /* no-op in production */ }
#endif
    
//MARK: обработчик входящего чата
    func setIncomingChatHandler(_ handler: @escaping (ChatMessage) -> Void) {
        self.incomingChatHandler = handler
    }
    
//MARK: API: возвращает текущее состояние подключения и task (если есть)
    func currentConnectionInfo() -> (isConnected: Bool, task: URLSessionWebSocketTask?) {
            return (isConnectedInternal, webSocketTask)
        }

//MARK:  Подключиться к WebSocket.
//    / - Parameters:
//    /   - chatId: optional — если соединение связано с конкретным чатом (orderId), можно передать chatId
//    /   - orderId: optional — текущий orderId (полезно для слушания order-specific каналов)
//    / Поведение: если уже подключено — ничего не делает (или можно форсировать reconnect)
    func connect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            // Если уже подключены — ничего не делаем
            if self.isConnectedInternal {
                return
            }
            // Запуск асинхронной процедуры (используем Task, чтобы можно было await)
            Task.detached { [weak self] in
                await self?.establishConnection()
            }
        }
    }
    
//MARK: Отключиться корректно
    func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self._disconnectInternal(reason: .goingAway)
        }
    }
    

//MARK: Отправить ChatMessage (буферизуется при отсутствии соединения)
    
    func sendMessage(_ msg: ChatMessage) {
        outgoingBufferManager.enqueue(msg)
        if isConnectedInternal, let task = webSocketTask {
            outgoingBufferManager.flush(using: task) { result in
                if case .failure(let err) = result {
                    print("Flush failed:", err)
                }
            }
        }
    }

//MARK: Универсальная отправка envelope (Encodable payload)
     func sendEnvelope<T: Encodable>(type: WSMessageType, orderId: String? = nil, payload: T?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var payloadData: Data? = nil
            if let p = payload {
                payloadData = try? self.encoder.encode(AnyEncodable(p))
            }
            let env = WSEnvelope(type: type, orderId: orderId, payload: payloadData, meta: nil)
            do {
                let envData = try self.encoder.encode(env)
                if let text = String(data: envData, encoding: .utf8) {
                    if self.isConnectedInternal, let task = self.webSocketTask {
                        task.send(.string(text)) { error in
                            if let error = error {
                                print("WS send envelope error:", error)
                                // Если это chatMessage payload, можно буферизовать — но здесь мы не делаем этого для всех типов
                            }
                        }
                    } else {
                        // Для chatMessage сохраним в буфер, иначе логируем
                        if type == .chatMessage, let payloadData = payloadData,
                           let chatMsg = try? self.decoder.decode(ChatMessage.self, from: payloadData) {
                            self.enqueueMessage(chatMsg)
                        } else {
                            print("WS not connected — envelope not sent (type: \(type))")
                        }
                    }
                }
            } catch {
                print("WS encode envelope error:", error)
            }
        }
    }

    
//MARK: Курьер принимает заказ — отправляем событие на сервер (через WS)
    /// Сервер ожидает envelope типа .courierAccepted / .courierDeclined или REST вызов (зависит от контракта)
     func acceptOrderAsCourier(orderId: String, courierId: Int) {
        // Пример payload: { "courierId": 42, "accepted": true }
        let payload: [String: AnyEncodable] = [
            "courierId": AnyEncodable(courierId),
            "accepted": AnyEncodable(true)
        ]
        sendEnvelope(type: .courierAccepted, orderId: orderId, payload: payload)
    }

     func declineOrderAsCourier(orderId: String, courierId: Int) {
        let payload: [String: AnyEncodable] = [
            "courierId": AnyEncodable(courierId),
            "accepted": AnyEncodable(false)
        ]
        sendEnvelope(type: .courierDeclined, orderId: orderId, payload: payload)
    }

//MARK: Покупатель отменяет заказ — можно отправить через WS или через REST (напр. REST предпочтительнее для авторитарных операций)
     func cancelOrder(orderId: String, reason: String? = nil) {
        let payload = reason.map { ["reason": AnyEncodable($0)] }
        sendEnvelope(type: .orderCancelled, orderId: orderId, payload: payload)
    }

//MARK: Основная процедура установления соединения.
    private func establishConnection() async {
        // 0. Проверяем, не подключены ли уже
        if queue.sync(execute: { isConnectedInternal }) {
            return // уже подключены — выходим
        }

        // 1. Обновляем accessToken при необходимости
        do {
            let refreshed = try await authService.refreshIfNeeded()
            if !refreshed {
                print("⚠️ WS: токен не удалось обновить — прекращаем подключение")
                DispatchQueue.main.async {
                    self.onClose?(NSError(domain: "WebSocket", code: 401, userInfo: [NSLocalizedDescriptionKey: "Auth refresh failed"]))
                }
                return
            }
        } catch {
            print("⚠️ WS: refreshIfNeeded() завершился с ошибкой:", error)
            DispatchQueue.main.async {
                self.onClose?(error)
            }
            return
        }

        // 2. Формируем URL с query-параметрами
        var requestURL = wsURL
        if let chatId = currentChatId, !chatId.isEmpty {
            if var comps = URLComponents(url: wsURL, resolvingAgainstBaseURL: false) {
                var q = comps.queryItems ?? []
                q.append(URLQueryItem(name: "chatId", value: chatId))
                comps.queryItems = q
                if let u = comps.url { requestURL = u }
            }
        } else if let orderId = currentOrderId, !orderId.isEmpty {
            if var comps = URLComponents(url: wsURL, resolvingAgainstBaseURL: false) {
                var q = comps.queryItems ?? []
                q.append(URLQueryItem(name: "orderId", value: orderId))
                comps.queryItems = q
                if let u = comps.url { requestURL = u }
            }
        }

        var req = URLRequest(url: requestURL)
        req.timeoutInterval = 30

        // 3. Добавляем Authorization header
        if let token = await authService.getAccessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("⚠️ WS: отсутствует accessToken — не подключаемся")
            DispatchQueue.main.async {
                self.onClose?(NSError(domain: "WebSocket", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing access token"]))
            }
            return
        }

        // 4. Создаём и запускаем соединение
        queue.async { [weak self] in
            guard let self = self else { return }

            // Закрываем старое соединение, если оно было
            self._disconnectInternal(reason: .goingAway)

            let task = self.session.webSocketTask(with: req)
            self.webSocketTask = task
            task.resume()

            // Обновляем состояние
            self.isConnectedInternal = true
            self.reconnectAttempts = 0

            // Уведомляем об открытии
            DispatchQueue.main.async {
                self.onOpen?()
            }

            // Запускаем основные циклы
            self.startReceiveLoop()
            self.startPingLoop()
            self.flushOutgoingBuffer()
        }
    }
//MARK: Закрытие соединения в контексте queue
    private func _disconnectInternal(reason: URLSessionWebSocketTask.CloseCode) {
        // Остановить задачи
        listeningTask?.cancel()
        listeningTask = nil

        pingTask?.cancel()
        pingTask = nil

        if let task = webSocketTask {
            task.cancel(with: reason, reason: nil)
            webSocketTask = nil
        }
        isConnectedInternal = false
    }

// MARK: - Receive loop
    // Запускаем рекурсивный цикл чтения сообщений от сервера в отдельном Task
    private func startReceiveLoop() {
        listeningTask?.cancel()
        listeningTask = Task.detached { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                do {
                    guard let task = self.webSocketTask else { throw URLError(.badServerResponse) }
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            self.handleIncomingData(data)
                        } else {
                            print("WS: received string but failed to convert to Data")
                        }
                    case .data(let data):
                        self.handleIncomingData(data)
                    @unknown default:
                        print("WS: received unknown message type")
                    }
                } catch {
                    // Ошибка чтения — инициируем reconnect
                    print("WS receive error:", error)
                    self.queue.async {
                        self.isConnectedInternal = false
                        DispatchQueue.main.async { self.onClose?(error) }
                        self.scheduleReconnect()
                    }
                    break
                }
            }
        }
    }
    
//MARK: - Главный обработчик входящих данных
   
    private func handleIncomingData(_ data: Data) {
        if let env = decode(WSEnvelope.self, from: data) {
            switch env.type {
            case .newOrderForCourier:
                // payload должен содержать OrderModel, expiresIn
                if let payload = env.payload {
                    if let order: OrderModel = decodeNested(OrderModel.self, key: "order", from: payload),
                       let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any],
                       let expires = dict["expiresIn"] as? Int {
                        DispatchQueue.main.async { self.onNewOrderForCourier?(order, expires) }
                        // обновляем локальную запись (если нужно)
                        updateLocalOrderFromServer(order)
                    } else {
                        print("WS: newOrderForCourier: failed to decode nested order or expiresIn")
                    }
                }

            case .orderAssigned:
                // payload: CourierModel в корне
                if let payload = env.payload {
                    if let courier = decode(CourierModel.self, from: payload), let orderId = env.orderId {
                        DispatchQueue.main.async { self.onOrderAssigned?(orderId, courier) }
                    } else if let courier = decodeNested(CourierModel.self, key: "courier", from: payload), let orderId = env.orderId {
                        DispatchQueue.main.async { self.onOrderAssigned?(orderId, courier) }
                    } else {
                        print("WS: orderAssigned: failed to decode courier")
                    }
                }

            case .orderCancelled:
                // payload: optional
                var reason: String? = nil
                if let payload = env.payload,
                   let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] {
                    reason = dict["reason"] as? String
                }
                if let orderId = env.orderId {
                    DispatchQueue.main.async { self.onOrderCancelled?(orderId, reason) }
                }

            case .orderUpdated:
                // payload: OrderModel full
                if let payload = env.payload, let order = decode(OrderModel.self, from: payload) {
                    // Сохранение/обновление локальной копии
                    updateLocalOrderFromServer(order)
                    DispatchQueue.main.async {
                        self.onOrderUpdated?(order)
                        // special: если статус у тебя называется .done (или .completed) — адаптируй
                        if order.status == .done || order.status.rawValue == "done" {
                            guard let orderId = order.id ?? nil else { return }
                            self.onOrderDone?(orderId)
                        }
                    }
                } else {
                    print("WS: orderUpdated: failed to decode OrderModel")
                }

            case .orderDone:
                if let orderId = env.orderId {
                    DispatchQueue.main.async { self.onOrderDone?(orderId) }
                }

            case .updateCourierLocation:
                // payload: "lat", "lon"
                if let payload = env.payload,
                   let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any],
                   let lat = dict["lat"] as? Double, let lon = dict["lon"] as? Double,
                   let orderId = env.orderId {
                    DispatchQueue.main.async { self.onUpdateCourierLocation?(orderId, lat, lon) }
                }

            case .chatMessage:
                // payload: ChatMessage
                if let payload = env.payload, let msg = decode(ChatMessage.self, from: payload) {
                    DispatchQueue.main.async { self.incomingChatHandler?(msg)}
                } else {
                    print("WS: chatMessage: failed to decode ChatMessage")
                }

            case .courierAccepted, .courierDeclined:
                // payload  CourierModel
                if let payload = env.payload {
                    var courier: CourierModel? = nil
                    if let dec = decode(CourierModel.self, from: payload) {
                        courier = dec
                    } else if let nested = decodeNested(CourierModel.self, key: "courier", from: payload) {
                        courier = nested
                    }
                    if let courier = courier, let orderId = env.orderId {
                        DispatchQueue.main.async {
                            if env.type == .courierAccepted {
                                self.onCourierAccepted?(orderId, courier)
                            } else {
                                self.onCourierDeclined?(orderId, courier, true)
                            }
                        }
                    } else {
                        print("WS: courierAccepted/Declined: could not decode courier or missing orderId")
                    }
                }

            case .orderCreatedAck:
                // Пайлоуд может содержать OrderModel, "status", "serverOrderId", или сам OrderModel
                if let payload = env.payload {
                    if let serverOrder = decode(OrderModel.self, from: payload) {
                        // Обновляем локальную запись
                        updateLocalOrderFromServer(serverOrder)
                    } else if let order: OrderModel = decodeNested(OrderModel.self, key: "order", from: payload) {
                        updateLocalOrderFromServer(order)
                    } else if let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] {
                        // попытаться собрать OrderModel вручную (fallback)
                        if let orderObj = dict["order"],
                           let orderData = try? JSONSerialization.data(withJSONObject: orderObj, options: []),
                           let serverOrder = decode(OrderModel.self, from: orderData) {
                            updateLocalOrderFromServer(serverOrder)
                        } else {
                            print("WS: orderCreatedAck: unknown payload format", dict.keys)
                        }
                    } else {
                        print("WS: orderCreatedAck: failed to decode payload")
                    }
                }

            case .heartbeat:
                // можно логировать или обновить lastSeen
                break

            // если у тебя есть другие типы — обрабатываем их здесь
            default:
                // по умолчанию — игнорируем, но логируем
                print("WS: unhandled envelope type \(env.type)")
            }

            // Envelope обработан — exit
            return
        }

        // 2) Fallback: если это не WSEnvelope — пробуем декодировать ChatMessage напрямую
        if let msg = decode(ChatMessage.self, from: data) {
            DispatchQueue.main.async { self.incomingChatHandler?(msg) }
            return
        }

        // 3) Ничего не распознали — логируем
        print("WS: received unknown payload (could not decode envelope or ChatMessage)")
    }

// MARK: -  Исходящий буфер (enqueue / flush / persistence)
    private func enqueueMessage(_ msg: ChatMessage) {
        /// Мы можем вызывать из любой очереди — OutgoingBuffer сам защищён своей serial-очередью,
        /// но чтобы сохранить порядок логики WebSocket используем вашу очередь:
        queue.async { [weak self] in
            guard let self = self else { return }

            /// Просто добавляем в менеджер буфера
            self.outgoingBufferManager.enqueue(msg)

            /// Если уже подключены — инициируем попытку отправки
            if self.isConnectedInternal, let task = self.webSocketTask, self.isBufferRestored {
                self.outgoingBufferManager.flush(using: task) { result in
                    if case .failure(let err) = result {
                        print("enqueue -> flush failed:", err)
                    }
                }
            }
        }
    }
//MARK: очистка исходящего буфера
    private func flushOutgoingBuffer() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.isBufferRestored else {
                // ещё не восстановили буфер с диска — ничего не делаем
                return
            }
            guard self.isConnectedInternal, let task = self.webSocketTask else { return }

            // Делегируем всю последовательную логику отправки буферу
            self.outgoingBufferManager.flush(using: task) { result in
                switch result {
                case .success:
                    // при необходимости лог/метрика
                    // Заметь: remove persisted buffer выполняется внутри OutgoingBuffer после полного отправления
                    break
                case .failure(let err):
                    // flush остановится на первой ошибке и вернёт ошибку здесь
                    print("WS flush error (via buffer):", err)
                }
            }
        }
    }
//MARK: сохранить исходящий буфер на диск
    private func saveOutgoingBufferToDisk() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.outgoingBufferManager.saveNow()
        }
    }
//MARK: восстановление буфера с диска
    private func restoreOutgoingBufferFromDisk(completion: (() -> Void)? = nil) {
        // restoreFromDisk выполнит чтение на фоне внутри OutgoingBuffer (мы подразумеваем такой API)
        // и вызовет completion на своей очереди — для безопасности приведём результат к нашей queue.
        outgoingBufferManager.restoreFromDisk { [weak self] in
            guard let self = self else { return }
            self.queue.async {
                self.isBufferRestored = true
                completion?()
                // Если уже подключены, запустим flush
                if self.isConnectedInternal, let task = self.webSocketTask {
                    self.outgoingBufferManager.flush(using: task) { result in
                        if case .failure(let err) = result {
                            print("flush after restore failed:", err)
                        }
                    }
                }
            }
        }
    }
    // -------------------------------------------------------------------------
    //  Ping / heartbeat
    // -------------------------------------------------------------------------
    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task.detached { [weak self] in
            guard let self = self else { return }
            let pingIntervalSeconds: UInt64 = 25
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: pingIntervalSeconds * 1_000_000_000)
                    guard let task = self.webSocketTask else { continue }
                    let semaphore = DispatchSemaphore(value: 0)
                    var pingError: Error? = nil
                    task.sendPing { error in
                        if let e = error {
                            pingError = e
                        }
                        semaphore.signal()
                    }
                    // дождёмся завершения ping или timeout
                    let waitResult = semaphore.wait(timeout: .now() + .seconds(10))
                    if waitResult == .timedOut {
                        // ping не подтвердился -> reconnect
                        print("WS ping timed out -> reconnect")
                        self.queue.async {
                            self.isConnectedInternal = false
                            DispatchQueue.main.async { self.onClose?(nil) }
                            self.scheduleReconnect()
                        }
                        break
                    } else if let err = pingError {
                        // ping вернул ошибку -> reconnect
                        print("WS ping returned error:", err)
                        self.queue.async {
                            self.isConnectedInternal = false
                            DispatchQueue.main.async { self.onClose?(err) }
                            self.scheduleReconnect()
                        }
                        break
                    } else {
                        // ping OK -> continue
                    }
                } catch {
                    // task cancelled или ошибка sleep
                    break
                }
            }
        }
    }

//MARK:  Планирование повторного подключения
    private func scheduleReconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.isConnectedInternal { return } // если уже подключились — не нужно
            self.reconnectAttempts += 1
            if self.reconnectAttempts > self.maxReconnectAttempts {
                // превышен лимит — оповестим и остановим попытки
                DispatchQueue.main.async { self.onClose?(nil) }
                return
            }
            // вычислим задержку (экспоненциальный backoff с ограничением)
            let delay = min(self.reconnectBaseDelay * pow(2.0, Double(self.reconnectAttempts - 1)), self.reconnectMaxDelay)
            print("WS schedule reconnect in \(delay)s (attempt \(self.reconnectAttempts))")
            Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let self = self else { return }
                self.queue.async {
                    // если сохранили chatId/orderId — reconnect автоматически с ними
                    self.connect()
                }
            }
        }
    }
}
extension WebSocketService {
   
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // декодирование могло упасть — лог для отладки
            print("WS decode error for type \(T.self):", error)
            return nil
        }
    }
    
//MARK: Декодирует вложенный объект под ключом `key` в JSON-пайлоуде.
    /// Например: payload = { "order": {...}, "expiresIn": 123 }
    private func decodeNested<T: Decodable>(_ type: T.Type, key: String, from data: Data) -> T? {
        /// Попробуем распарсить как словарь ([String: Any]) безопасно — через JSONSerialization,
        /// затем взять значение по ключу и декодировать его обратно в Data -> T
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = json as? [String: Any],
            let nested = dict[key]
        else {
            return nil
        }
        // Пытаемся сериализовать вложенный объект обратно в Data и декодировать
        if let nestedData = try? JSONSerialization.data(withJSONObject: nested, options: []) {
            return decode(type, from: nestedData)
        } else {
            return nil
        }
    }
    
//MARK: Обновляет локальное хранилище (CoreData) на основе пришедшего serverOrder.
    /// Пытаемся использовать idempotencyKey если он есть; иначе пытаемся найти по serverId; иначе просто сохраняем новый объект под ключом order::<idempotencyKey or serverId>
    private func updateLocalOrderFromServer(_ serverOrder: OrderModel) {
        
        do {
            
        }
        
        
        //let ctx = coreData.newBackgroundContext()

//        ctx.performAndWait {
//            do {
//                if let idem = serverOrder.idempotencyKey, !idem.isEmpty {
//                    let key = "order::\(idem)"
//                    try coreData.save(serverOrder, forKey: key, context: ctx)
//                    return
//                }
//
//                if let serverId = serverOrder.id, !serverId.isEmpty {
//                    let localOrders: [OrderModel] = try coreData.loadAll(OrderModel.self, context: ctx)
//                    if let idx = localOrders.firstIndex(where: { $0.id == serverId }) {
//                        let local = localOrders[idx]
//                        if ((local.idempotencyKey?.isEmpty) == nil) {
//                            let key = "order::\(local.idempotencyKey)"
//                            try coreData.save(serverOrder, forKey: key, context: ctx)
//                            return
//                        }
//                    }
//                    let fallbackKey = "order::serverId::\(serverId)"
//                    try coreData.save(serverOrder, forKey: fallbackKey, context: ctx)
//                    return
//                }
//
//                let fallback = "order::unknown::\(UUID().uuidString)"
//                try coreData.save(serverOrder, forKey: fallback, context: ctx)
//            } catch {
//                print("WS: failed to update local order from server:", error)
//            }
//        }
    }
}
