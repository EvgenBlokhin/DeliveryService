//
//  WebSocketService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation

final class WebSocketService {

    // MARK: - Singleton
    public static let shared = WebSocketService()
    

    //  Конфигурация (замените на ваш URL)
    /// Укажите реальный WebSocket URL (wss://...)
    private let wsURLString: String = "wss://api.example.com/socket"
    private var wsURL: URL { URL(string: wsURLString)! }

    //  JSON
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    //  URLSession / Tasks
    private var session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var listeningTask: Task<Void, Never>?   // receive loop
    private var pingTask: Task<Void, Never>?        // ping loop

    //  State + concurrency
    /// Serial queue для защиты внутреннего состояния (thread-safety)
    private let queue = DispatchQueue(label: "com.coffeedelivery.websocket.queue")

    /// Внутренний булев флаг (читается/писается в queue)
    private var isConnectedInternal: Bool = false

    /// Для автопереподключения
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 8
    private let reconnectBaseDelay: TimeInterval = 1.0
    private let reconnectMaxDelay: TimeInterval = 60.0

    //  Outgoing buffer
    /// FIFO буфер для ChatMessage (если соединение отсутствует)
    private var outgoingBuffer: [ChatMessage] = []
    private let maxBufferCount: Int = 1000
    /// Персистенция буфера (опционально) — ключ UserDefaults
    private let bufferStorageKey = "WebSocketService.outgoingBuffer.v1"
    private let persistBufferOnDisk: Bool = true // можно включить/выключить

    // Автосохранённые параметры подключения
    /// Если нужно — сохраняем chatId / orderId чтобы service мог автоматически переподключаться
    private var currentChatId: String?
    private var currentOrderId: String?

    // Callbacks (все вызываются на main thread)
    public var onOpen: (() -> Void)?
    public var onClose: ((Error?) -> Void)?

    // Бизнес-колбэки
    var onNewOrderForCourier: ((OrderModel, Int) -> Void)?    // (order, expiresInSeconds)
    var onOrderAssigned: ((Int, CourierModel) -> Void)?    // (orderId, courier)
    var onOrderCancelled: ((Int, String?) -> Void)?        // (orderId, optional reason)
    var onOrderUpdated: ((OrderModel) -> Void)?
    var onOrderDone: ((Int) -> Void)?                      // orderId
    var onLocationUpdate: ((Int, Double, Double) -> Void)? // (orderId, lat, lon)
    var onChatMessage: ((Int, ChatMessage) -> Void)?    // (orderId, message)
    var onCourierAccepted: ((Int, CourierModel) -> Void)?   // (orderId, courier)
    var onCourierDeclined: ((Int, CourierModel, Bool) -> Void)? // (orderId, courier, shouldRemoveAnnotation)

    //  Init / Deinit
    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        session = URLSession(configuration: cfg)

        // восстановление буфера при старте (если включено)
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

    // -------------------------------------------------------------------------
    //  Public API
    // -------------------------------------------------------------------------

//    / Подключиться к WebSocket.
//    / - Parameters:
//    /   - chatId: optional — если соединение связано с конкретным чатом (orderId), можно передать chatId
//    /   - orderId: optional — текущий orderId (полезно для слушания order-specific каналов)
//    / Поведение: если уже подключено — ничего не делает (или можно форсировать reconnect)
    public func connect(chatId: String? = nil, orderId: String? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let c = chatId { self.currentChatId = c }
            if let o = orderId { self.currentOrderId = o }
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

    /// Отключиться корректно
    public func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self._disconnectInternal(reason: .goingAway)
        }
    }

    // Отправить ChatMessage (буферизуется при отсутствии соединения)
    func sendChatMessage(_ msg: ChatMessage) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.isConnectedInternal, let task = self.webSocketTask {
                // Отправляем как текстовый JSON
                do {
                    let data = try self.encoder.encode(msg)
                    if let text = String(data: data, encoding: .utf8) {
                        task.send(.string(text)) { [weak self] error in
                            if let error = error {
                                print("WS send error:", error)
                                // при ошибке — буферизуем сообщение
                                self?.enqueueMessage(msg)
                            }
                        }
                    } else {
                        self.enqueueMessage(msg)
                    }
                } catch {
                    print("WS encode error:", error)
                    self.enqueueMessage(msg)
                }
            } else {
                self.enqueueMessage(msg)
            }
        }
    }

    // Универсальная отправка envelope (Encodable payload)
    public func sendEnvelope<T: Encodable>(type: WSMessageType, orderId: Int? = nil, payload: T?) {
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

    //  Courier actions (accept/decline) and customer actions (cancel)
    /// Курьер принимает заказ — отправляем событие на сервер (через WS)
    /// Сервер ожидает envelope типа .courierAccepted / .courierDeclined или REST вызов (зависит от контракта)
    public func acceptOrderAsCourier(orderId: Int, courierId: Int) {
        // Пример payload: { "courierId": 42, "accepted": true }
        let payload: [String: AnyEncodable] = [
            "courierId": AnyEncodable(courierId),
            "accepted": AnyEncodable(true)
        ]
        sendEnvelope(type: .courierAccepted, orderId: orderId, payload: payload)
    }

    public func declineOrderAsCourier(orderId: Int, courierId: Int) {
        let payload: [String: AnyEncodable] = [
            "courierId": AnyEncodable(courierId),
            "accepted": AnyEncodable(false)
        ]
        sendEnvelope(type: .courierDeclined, orderId: orderId, payload: payload)
    }

    /// Покупатель отменяет заказ — можно отправить через WS или через REST (напр. REST предпочтительнее для авторитарных операций)
    public func cancelOrder(orderId: Int, reason: String? = nil) {
        let payload = reason.map { ["reason": AnyEncodable($0)] }
        sendEnvelope(type: .orderCancelled, orderId: orderId, payload: payload)
    }

    // -------------------------------------------------------------------------
    //  Internal connection helpers
    // -------------------------------------------------------------------------

    /// Основная процедура установления соединения.
    /// Выполняется в Task, чтобы была возможность await (для token refresh и т.п.).
    private func establishConnection() async {
        // 1) Попробуем обновить токен через AuthService, если он есть в проекте.
        // Это нужно, чтобы WS подключался с актуальным Access Token (Bearer).
        if let authServiceType = NSClassFromString("AuthService") {
            // Если AuthService реализован — пробуем вызвать refreshIfNeeded (await)
            // Здесь мы используем try? await чтобы не падать при ошибке refresh
                do {
                    // Метод refreshIfNeeded() предполагается асинхронным в вашем проекте; в противном случае закомментируйте.
                    if #available(iOS 15.0, *) {
                         try await AuthService.shared.refreshToken()
                    }
                } catch {
                    print("WS: token refresh failed, continue with existing token:", error)
                }
            }

        // 2) Формируем URLRequest (добавим chatId или orderId в query, если нужно)
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

        // 3) Вставим Authorization header из Keychain, если доступен
        if let token = try? KeychainHelper.shared.readData(for: "accessToken") {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 4) Создаём task и запускаем
        queue.async { [weak self] in
            guard let self = self else { return }
            // при новом подключении корректно отключаем старые ресурсы
            self._disconnectInternal(reason: .goingAway)
            let task = self.session.webSocketTask(with: req)
            self.webSocketTask = task
            task.resume()
            self.isConnectedInternal = true
            self.reconnectAttempts = 0
            // уведомляем на main
            DispatchQueue.main.async { self.onOpen?() }
            // Запускаем receive loop и ping loop и пытаемся отправить буфер
            self.startReceiveLoop()
            self.startPingLoop()
            self.flushOutgoingBuffer()
        }
    }

    /// Закрытие соединения в контексте queue
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

    // -------------------------------------------------------------------------
    // MARK: - Receive loop
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Handle incoming messages (envelope + fallback)
    // -------------------------------------------------------------------------
    // Обработка входящих байтов данных. Сначала пробуем WSEnvelope, затем fallback на ChatMessage
    private func handleIncomingData(_ data: Data) {
        // 1) Попытка десериализовать как WSEnvelope
        if let env = try? decoder.decode(WSEnvelope.self, from: data) {
            // Обрабатываем по типу
            switch env.type {
            case .newOrderForCourier: ///новый Заказ Для Курьера
                /// payload должен содержать { "order": OrderModel, "expiresIn": Int }
                if let payload = env.payload {
                    if let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] {
                        if let orderData = try? JSONSerialization.data(withJSONObject: dict["order"] ?? [:], options: []),
                           let order = try? decoder.decode(OrderModel.self, from: orderData),
                           let expires = dict["expiresIn"] as? Int {
                            DispatchQueue.main.async { self.onNewOrderForCourier?(order, expires) }
                        }
                    }
                }
            case .orderAssigned: ///назначенный заказ
                /// payload: { "courier": CourierModel }
                if let payload = env.payload {
                    if let courier = try? decoder.decode(CourierModel.self, from: payload) {
                        if let orderId = env.orderId {
                            DispatchQueue.main.async { self.onOrderAssigned?(orderId, courier) }
                        }
                    }
                }
            case .orderCancelled: ///ордер отменен
                // payload: { "reason": "..." } (optional)
                var reason: String? = nil
                if let payload = env.payload {
                    if let d = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] {
                        reason = d["reason"] as? String
                    }
                }
                if let orderId = env.orderId {
                    DispatchQueue.main.async { self.onOrderCancelled?(orderId, reason) }
                }
            case .orderUpdated:
                // payload: OrderModel full
                if let payload = env.payload, let order = try? decoder.decode(OrderModel.self, from: payload) {
                    DispatchQueue.main.async { self.onOrderUpdated?(order) }
                    // special: if status == .done -> onOrderDone
                    if order.status == .done {
                        DispatchQueue.main.async { self.onOrderDone?(order.id) }
                    }
                }
            case .orderDone:
                if let orderId = env.orderId {
                    DispatchQueue.main.async { self.onOrderDone?(orderId) }
                }
            case .updateCourierLocation:
                // payload: { "lat": Double, "lon": Double }
                if let payload = env.payload,
                   let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any],
                   let lat = dict["lat"] as? Double, let lon = dict["lon"] as? Double,
                   let orderId = env.orderId {
                    DispatchQueue.main.async { self.onLocationUpdate?(orderId, lat, lon) }
                }
            case .chatMessage:
                // payload: ChatMessage
                if let payload = env.payload, let msg = try? decoder.decode(ChatMessage.self, from: payload) {
                    DispatchQueue.main.async { self.onChatMessage?(msg.orderId, msg) }
                }
            case .courierAccepted, .courierDeclined: ///курьер найден, курьер отказался
                // обрабатывать по необходимости — логируем
                // heartbeat может использоваться как application-level подтверждение
                // orderCreatedAck может содержать serverOrderId/status
                // courierAccepted/Declined — можно уведомлять UI если нужно
                // Для now — пробуем парсить payload как OrderModel/разное
                
                guard let payload = env.payload else { break }
                   // Попробуем извлечь CourierModel из payload:
                   var courier: CourierModel? = nil

                   // 1) Попытка декодировать напрямую как CourierModel
                   if let decoded = try? decoder.decode(CourierModel.self, from: payload) {
                       courier = decoded
                   } else {
                       // 2) Попытка распарсить как словарь, который содержит ключ "courier"
                       if let dict = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] {
                           if let courierObj = dict["courier"] {
                               if let courierData = try? JSONSerialization.data(withJSONObject: courierObj, options: []),
                                  let decoded = try? decoder.decode(CourierModel.self, from: courierData) {
                                   courier = decoded
                               }
                           } else {
                               // возможно payload содержит дополнительные поля, например { "courier": {...}, "note": "..." }
                               // либо курьер в корне как ключи — уже обработали выше, но оставим лог
                               print("WS: courier key not found in payload dict:", dict.keys)
                           }
                       }
                   }

                   // Если удалось получить courier и orderId — вызовем соответствующие колбэки
                   if let courier = courier, let orderId = env.orderId {
                       DispatchQueue.main.async {
                           if env.type == .courierAccepted {
                               self.onCourierAccepted?(orderId, courier)
                           } else { // .courierDeclined
                               // передаём флаг shouldRemoveAnnotation = true — UI удалит аннотацию
                               self.onCourierDeclined?(orderId, courier, true)
                           }
                       }
                   } else {
                       // Логируем, если не распознали курьера
                       log("WS: courierAccepted/Declined received but failed to decode courier or missing orderId")
                   }
                
                
                
                
                if env.type == .orderCreatedAck {
                    if let payload = env.payload, let info = try? JSONSerialization.jsonObject(with: payload, options: []) as? [String: Any] {
                        // например: serverOrderId, status
                        log("WS orderCreatedAck payload:", info)
                    }
                }
            case.orderCreatedAck, .heartbeat:
                
                
                break
            }
            return
        }

        // 2) Fallback: если это не WSEnvelope — пробуем декодировать ChatMessage напрямую
        if let msg = try? decoder.decode(ChatMessage.self, from: data) {
            DispatchQueue.main.async { self.onChatMessage?(msg.orderId, msg) }
            return
        }

        // 3) Ничего не распознали — логируем
        print("WS: received unknown payload (could not decode envelope or chatMessage)")
    }

    // -------------------------------------------------------------------------
    //  Outgoing buffer (enqueue / flush / persistence)
    // -------------------------------------------------------------------------
    private func enqueueMessage(_ msg: ChatMessage) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.outgoingBuffer.count >= self.maxBufferCount {
                // policy: удаляем самый старый, чтобы вместить новое
                self.outgoingBuffer.removeFirst()
            }
            self.outgoingBuffer.append(msg)
            if self.persistBufferOnDisk {
                self.saveOutgoingBufferToDisk()
            }
        }
    }

    private func flushOutgoingBuffer() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.isConnectedInternal, let task = self.webSocketTask else { return }
            while !self.outgoingBuffer.isEmpty {
                let msg = self.outgoingBuffer.removeFirst()
                do {
                    let data = try self.encoder.encode(msg)
                    if let text = String(data: data, encoding: .utf8) {
                        task.send(.string(text)) { error in
                            if let error = error {
                                print("WS flush send error:", error)
                                // при ошибке — возвращаем сообщение в начало и прерываем flush
                                self.queue.async { self.outgoingBuffer.insert(msg, at: 0); if self.persistBufferOnDisk { self.saveOutgoingBufferToDisk() } }
                            } else {
                                // успешно отправлено — обновим persisted buffer
                                if self.persistBufferOnDisk { self.saveOutgoingBufferToDisk() }
                            }
                        }
                    } else {
                        // can't convert to string — пропускаем, но логируем
                        print("WS flush: couldn't convert encoded ChatMessage to String")
                    }
                } catch {
                    print("WS flush encode error:", error)
                }
                // brief yield — чтобы не заблокировать event loop (необязательный)
                Thread.sleep(forTimeInterval: 0.005)
            }
            // после успешной отправки очистим persisted buffer
            if self.persistBufferOnDisk { self.saveOutgoingBufferToDisk() }
        }
    }

    private func saveOutgoingBufferToDisk() {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(self.outgoingBuffer)
                UserDefaults.standard.set(data, forKey: self.bufferStorageKey)
            } catch {
                print("WS save buffer error:", error)
            }
        }
    }

    private func restoreOutgoingBufferFromDisk() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = UserDefaults.standard.data(forKey: self.bufferStorageKey) {
                do {
                    let arr = try self.decoder.decode([ChatMessage].self, from: data)
                    self.outgoingBuffer = arr
                } catch {
                    print("WS restore buffer decode error:", error)
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

    // -------------------------------------------------------------------------
    //  Reconnect logic
    // -------------------------------------------------------------------------
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
                    self.connect(chatId: self.currentChatId, orderId: self.currentOrderId)
                }
            }
        }
    }
}
