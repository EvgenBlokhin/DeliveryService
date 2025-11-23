//
//  OrdersService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
/// OrderManager — управление созданием заказов, локальным хранением и retry-логикой.
/// Dependencies:
/// - NetworkClient: должен быть инициализирован и предоставлен при создании OrderManager.
/// - CoreDataStorage.shared — универсальное key-value хранилище для Codable (мы его обсуждали ранее).
import Foundation
import CoreData
import Combine

final class OrderService {

    private let client: NetworkClient
    private let core: CoreDataStorage
    private(set) weak var webSocket: WebSocketService?

    private let createOrderPath: String
    private let defaultMaxAttempts = 5
    private let backoffBaseSeconds: Double = 1.0
    var onOrderUpdate: ((OrderModel) -> Void)?
    /// В памяти — счетчики попыток для текущей сессии
    private var attemptsInMemory: [String: Int] = [:]

    // MARK: Init
    init(client: NetworkClient, coreData: CoreDataStorage, createOrderPath: String = "/orders") {
        self.client = client
        self.core = coreData
        self.createOrderPath = createOrderPath
    }
    //MARK: устанавливаем webSocket после его инициализации
    func setWebSocket(_ ws: WebSocketService) {
            self.webSocket = ws
        }

    // MARK: Keys
    private func localKey(forIdempotencyKey idem: String) -> String {
        return "order::\(idem)"
    }

    private func serverKey(forServerId sid: String) -> String {
        return "order::serverId::\(sid)"
    }

    // MARK: Mapping OrderModel <-> OrderEntity

    private func entity(from model: OrderModel,
                        attempts: Int16 = 0,
                        needsSync: Bool = true) -> OrderEntity {
        // items, courier -> Data
        var itemsData: Data
        var courierData: Data
        do {
            itemsData = try JSONEncoder().encode(model.items)
            courierData = try JSONEncoder().encode(model.courier)
        } catch {
            itemsData = Data()
            courierData = Data()
            print("OrderService.entity(from:): failed to encode items for idempotencyKey \(model.idempotencyKey ?? "nil"): \(error)")
        }

        return OrderEntity(
            id: model.id,
            idempotencyKey: model.idempotencyKey ?? UUID().uuidString,
            userId: model.userId,
            machineId: Int64(model.machineId),
            createdAt: model.createdAt,
            status: model.status.rawValue,
            address: model.address,
            itemsData: itemsData,
            courier: courierData,
            attempts: attempts,
            needsSync: needsSync
        )
    }

    private func model(from entity: OrderEntity) -> OrderModel {
        // itemsData -> [CartItem]
        var items: [CartItem] = []
        var courier: [CourierModel] = []
        if !entity.itemsData.isEmpty {
            do {
                items = try JSONDecoder().decode([CartItem].self, from: entity.itemsData)
                courier = try JSONDecoder().decode([CourierModel].self, from: entity.courier ?? Data())
            } catch {
                print("OrderService.model(from:): failed to decode itemsData for \(entity.idempotencyKey):", error)
            }
        }

        let status = OrderStatus(rawValue: entity.status) ?? .created

        return OrderModel(
            id: entity.id,
            idempotencyKey: entity.idempotencyKey,
            machineId: Int(entity.machineId),
            userId: entity.userId,
            createdAt: entity.createdAt,
            status: status,
            address: entity.address,
            items: items,
            courier: courier
        )
    }

    // MARK: Attempts bookkeeping

    private func attempts(for idempotencyKey: String) -> Int {
        return attemptsInMemory[idempotencyKey] ?? 0
    }

    private func incrementAttempts(for idempotencyKey: String) {
        attemptsInMemory[idempotencyKey] = (attemptsInMemory[idempotencyKey] ?? 0) + 1
    }

    private func resetAttempts(for idempotencyKey: String) {
        attemptsInMemory[idempotencyKey] = nil
    }

    // MARK: Local persistence helpers

    /// Сохранить/перезаписать локальную копию заказа.
    /// Сохраняет OrderEntity под ключом "order::<idempotencyKey>".
    private func persistOrderLocally(_ order: OrderModel, context: NSManagedObjectContext? = nil) {
        var mutable = order
        if mutable.idempotencyKey == nil || mutable.idempotencyKey?.isEmpty == true {
            mutable.idempotencyKey = UUID().uuidString
        }
        let ent = entity(from: mutable, attempts: 0, needsSync: (mutable.id == nil))
        let key = localKey(forIdempotencyKey: ent.idempotencyKey)
        do {
            try core.save(ent, forKey: key, context: context)
        } catch {
            print("OrderService.persistOrderLocally: failed to save key=\(key):", error)
        }
    }

    /// Обновить локальную запись, когда пришёл ответ от сервера.
    /// Сохраняет entity с needsSync = false.
    private func updateLocalWithServerOrder(_ serverOrder: OrderModel) {
        let entity = entity(from: serverOrder, attempts: 0, needsSync: false)
        do {
            if !entity.idempotencyKey.isEmpty {
                try core.save(entity, forKey: localKey(forIdempotencyKey: entity.idempotencyKey))
                return
            }
            if let sid = entity.id, !sid.isEmpty {
                try core.save(entity, forKey: serverKey(forServerId: sid))
                return
            }
            try core.save(entity, forKey: "order::unknown::\(UUID().uuidString)")
            
        } catch {
            print("OrderService.updateLocalWithServerOrder: failed to save:", error)
        }
    }
    //MARK: Handle update
    
    private func handleSocketUpdate(_ order: OrderModel) {
        webSocket?.onOrderUpdated = { [weak self] order in
            guard let self = self else { return }
            updateLocalWithServerOrder(order)
            onOrderUpdate?(order)
        }
    }

    // MARK: Public API: create / retry

    func createOrder(order: OrderModel) async throws {
        
        var local = OrderModel(
            id: nil,
            idempotencyKey: nil,
            machineId: order.machineId,
            userId: order.userId,
            createdAt: Date(),
            status: .created,
            address: order.address,
            items: order.items,
            courier: []
        )

        if local.idempotencyKey == nil || local.idempotencyKey?.isEmpty == true {
            local.idempotencyKey = UUID().uuidString
        }
        let idem = local.idempotencyKey!

        // 1) persist locally before sending
        persistOrderLocally(local)

        var lastError: Error? = nil

        for attempt in 1...defaultMaxAttempts {
            incrementAttempts(for: idem)
            do {
                let serverOrder: OrderModel = try await client.request(
                    path: createOrderPath,
                    method: "POST",
                    body: local,
                    requiresAuth: true
                )
                // success: update local
                updateLocalWithServerOrder(serverOrder)
                resetAttempts(for: idem)
                onOrderUpdate?(serverOrder)
            } catch {
                lastError = error
                if attempt >= defaultMaxAttempts {
                    // leave local for later retry
                    throw error
                }
                // backoff + jitter
                let delaySeconds = backoffBaseSeconds * pow(2.0, Double(attempt - 1))
                let jitter = Double.random(in: -0.2...0.2) * delaySeconds
                let sleepSeconds = max(0.1, delaySeconds + jitter)
                let ns = UInt64(sleepSeconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: ns)
                // continue
            }
        }

        throw lastError ?? NSError(domain: "OrderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error in createOrder"])
    }

    func retryPendingOrders(maxAttemptsPerOrder: Int? = nil) {
        Task.detached { [weak self] in
            guard let self = self else { return }
            do {
                // load all entities (could be large — consider filtering keys(prefix:) if you group)
                let allEntities: [OrderEntity] = try self.core.loadAll(OrderEntity.self)
                let allModels = allEntities.map { self.model(from: $0) }

                // candidates: no server id and has idempotencyKey
                let candidates = allModels.filter { $0.id == nil && ($0.idempotencyKey?.isEmpty == false) }
                for candidate in candidates {
                    await self.retrySingleOrder(candidate, maxAttempts: maxAttemptsPerOrder)
                }
            } catch {
                print("OrderService.retryPendingOrders: failed to load local orders:", error)
            }
        }
    }

    @discardableResult
    func retrySingleOrder(_ localOrder: OrderModel, maxAttempts: Int? = nil) async -> Bool {
        guard let idem = localOrder.idempotencyKey, !idem.isEmpty else {
            print("OrderService.retrySingleOrder: missing idempotencyKey, skipping")
            return false
        }

        let attemptsLimit = maxAttempts ?? defaultMaxAttempts
        var lastError: Error? = nil

        for attempt in 1...attemptsLimit {
            incrementAttempts(for: idem)
            do {
                let serverOrder: OrderModel = try await client.request(
                    path: createOrderPath,
                    method: "POST",
                    body: localOrder,
                    requiresAuth: true
                )
                updateLocalWithServerOrder(serverOrder)
                resetAttempts(for: idem)
                return true
            } catch {
                lastError = error
                if attempt >= attemptsLimit {
                    print("OrderService.retrySingleOrder: reached attempts limit for \(idem), lastError:", error)
                    return false
                }
                let delaySeconds = backoffBaseSeconds * pow(2.0, Double(attempt - 1))
                let jitter = Double.random(in: -0.2...0.2) * delaySeconds
                let sleepSeconds = max(0.1, delaySeconds + jitter)
                let ns = UInt64(sleepSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }

        if let e = lastError { print("OrderService.retrySingleOrder: ended with error:", e) }
        return false
    }
    
    

    // MARK: - Load single / all local orders

    /// Load one local order by idempotencyKey. Returns nil if not found.
    func loadLocalOrder(byIdempotencyKey key: String) throws -> OrderModel? {
        do {
            if let ent: OrderEntity = try core.load(OrderEntity.self, forKey: localKey(forIdempotencyKey: key)) {
                return model(from: ent)
            } else {
                return nil
            }
        } catch {
            print("OrderService.loadLocalOrder(byIdempotencyKey:) error:", error)
            throw error
        }
    }

    //MARK: - Load all local orders and return array of OrderModel
    func loadAllLocalOrders() throws -> [OrderModel] {
        do {
            let ents: [OrderEntity] = try core.loadAll(OrderEntity.self)
            return ents.map { model(from: $0) }
        } catch {
            print("OrderService.loadAllLocalOrders: failed to load all entities:", error)
            throw error
        }
    }

    // MARK: - Delete / find helpers

    func removeLocalOrder(byIdempotencyKey key: String) {
        do {
            try core.remove(forKey: localKey(forIdempotencyKey: key))
        } catch {
            print("OrderService.removeLocalOrder:", error)
        }
    }

    func findLocalOrder(byServerId serverId: String) throws -> OrderModel? {
        do {
            let ents: [OrderEntity] = try core.loadAll(OrderEntity.self)
            if let found = ents.first(where: { $0.id != nil && $0.id == serverId }) {
                return model(from: found)
            }
            return nil
        } catch {
            print("OrderService.findLocalOrder(byServerId:):", error)
            throw error
        }
    }

    func currentAttempts(forIdempotencyKey key: String) -> Int {
        return attempts(for: key)
    }
}
