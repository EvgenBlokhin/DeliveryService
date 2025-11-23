//
//  OutgoingBuffer.swift
//  Nesicofe
//
//  Created by dev on 06/11/2025.
//
import Foundation

final class OutgoingBuffer<ChatMessage: Codable> {
    private let queue = DispatchQueue(label: "OutgoingBuffer.queue", qos: .utility)
    private var buffer: [ChatMessage] = []
    private let maxCount: Int
    private let storage: BufferStorage
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var pendingSaveWorkItem: DispatchWorkItem?
    private var saveDebounceInterval: TimeInterval = 0.25

    init(storage: BufferStorage,
                    storageKey: String = "outgoingBuffer",
                    maxCount: Int = 200,
                    saveDebounceInterval: TimeInterval = 0.25,
                    encoder: JSONEncoder = JSONEncoder(),
                    decoder: JSONDecoder = JSONDecoder()) {
            self.storage = storage
            self.storageKey = storageKey
            self.maxCount = maxCount
            self.saveDebounceInterval = saveDebounceInterval
            self.encoder = encoder
            self.decoder = decoder
        }

    // MARK: Добавить сообщение в буфер
    func enqueue(_ msg: ChatMessage) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.buffer.count >= self.maxCount {
                // policy: drop oldest
                self.buffer.removeFirst(self.buffer.count - self.maxCount + 1)
            }
            self.buffer.append(msg)
            self.scheduleSave()
        }
    }
    // Состояние: посмотреть первый элемент
    func peekFirst() -> ChatMessage? {
        var result: ChatMessage?
        queue.sync {
            result = buffer.first
        }
        return result
    }

    var count: Int {
        var c = 0
        queue.sync { c = buffer.count }
        return c
    }
    // Очищаем буфер и persistence
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.buffer.removeAll()
            self.cancelScheduledSave()
            do {
                try storage.remove(forKey: self.storageKey)
            } catch {
                print("remove buffer error:", error) }
        }
    }

    // MARK: - Persistence
    private func scheduleSave() {
        cancelScheduledSave()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            do {
                try storage.save(self.buffer, forKey: self.storageKey)
            } catch {
                print("OutgoingBuffer save error:", error)
            }
        }
        pendingSaveWorkItem = work
        queue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: work)
    }

    private func cancelScheduledSave() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
    }

    func saveNow() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.cancelScheduledSave()
            do {
                try storage.save(self.buffer, forKey: self.storageKey)
            } catch {
                print("OutgoingBuffer saveNow error:", error)
            }
        }
    }
    
    //MARK: Восстановить буфер из persistence (если storage == nil — сбросит буфер в [])
    /// completion вызывается после завершения восстановления — внутри внутренней serial queue.
    /// Если нужно, вызывающий код может выполнить `queue.async { ... }` или `DispatchQueue.main.async { ... }` в completion.
    func restoreFromDisk(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Отменим отложенную запись — сейчас мы загружаем явно
            self.cancelScheduledSave()
                // Нет persistence — просто очистим/инициализируем буфер и вызовем completion
            self.buffer = []
            completion?()
            return
        }

            do {
                if let array: [ChatMessage] = try storage.load([ChatMessage].self, forKey: self.storageKey) {
                    self.buffer = array
                } else {
                    self.buffer = []
                }
            } catch {
                print("OutgoingBuffer.restoreFromDisk: failed to load buffer:", error)
                self.buffer = []
            }

            // Восстановили — вызываем completion (внутри нашей очереди)
            completion?()
        }

    // MARK: - Flush: последовательная отправка сообщений через webSocketTask
    /// Последовательная отправка всех сообщений через URLSessionWebSocketTask
        /// - При ошибке отправки сообщение вернётся в начало буфера и flush завершится с ошибкой
        public func flush(using task: URLSessionWebSocketTask,
                          encoder: JSONEncoder? = nil,
                          completion: ((Result<Void, Error>) -> Void)? = nil) {
            queue.async { [weak self] in
                guard let self = self else { return }
                if self.buffer.isEmpty {
                    completion?(.success(())); return
                }

                func sendNext() {
                    guard !self.buffer.isEmpty else {
                        // всё отправлено — удаляем persistence
                        do { try self.storage.remove(forKey: self.storageKey) }
                        catch { print("OutgoingBuffer remove after flush error:", error) }
                        completion?(.success(()))
                        return
                    }

                    let msg = self.buffer.removeFirst()
                    do {
                        let data = try (encoder ?? self.encoder).encode(msg)
                        guard let text = String(data: data, encoding: .utf8) else {
                            // не получилось закодировать строку — пропускаем сообщение
                            sendNext(); return
                        }

                        task.send(.string(text)) { sendError in
                            self.queue.async {
                                if let sendError = sendError {
                                    // вставляем обратно и сохраняем
                                    self.buffer.insert(msg, at: 0)
                                    do { try self.storage.save(self.buffer, forKey: self.storageKey) }
                                    catch { print("OutgoingBuffer save after send failure:", error) }
                                    completion?(.failure(sendError))
                                    return
                                } else {
                                    // успешно отправили — отложенно сохраним текущее состояние
                                    self.scheduleSave()
                                    // продолжаем
                                    sendNext()
                                }
                            }
                        }
                    } catch {
                        print("OutgoingBuffer encode error:", error)
                        // пропускаем это сообщение и продолжаем
                        sendNext()
                    }
                }

                // запускаем отправку
                sendNext()
            }
        }
    }
