//
//  SimpleStorage.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation
import CoreData

/// Универсальная обёртка над Core Data для хранения Codable-объектов как Key-Value.
/// - Не требует .xcdatamodeld: модель создаётся программно (Entity "KeyValue").
/// - Позволяет сохранять любые T: Codable под строковым ключом, загружать и удалять.
/// - Поддерживает background context и безопасное сохранение.
final class CoreDataStorage {
    // singleton — аналог SimpleStorage.shared

    // Имя внутреннего persistent container (необязательно)
    private let containerName = "KeyValueStore"

    // NSPersistentContainer, инициализированный с программной моделью
    private(set) lazy var container: NSPersistentContainer = {
        // Создаём модель в коде
        let model = Self.makeManagedObjectModel()
        let container = NSPersistentContainer(name: containerName, managedObjectModel: model)

        // Настройка persistent store (SQLite, по умолчанию — файл в ApplicationSupport)
        let storeDescription = NSPersistentStoreDescription()
        // Комментарий: путь можно переопределить при необходимости (например для тестов useInMemory: true)
        storeDescription.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [storeDescription]

        container.loadPersistentStores { desc, error in
            if let error = error {
                fatalError("CoreData loadPersistentStores failed: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    // Для тестов/инструментов можно использовать in-memory хранилище
    init(useInMemoryStore: Bool = false) {
        if useInMemoryStore {
            // Если нужен in-memory контейнер — перехватим ленькую инициализацию и заменим store description
            let model = Self.makeManagedObjectModel()
            let container = NSPersistentContainer(name: containerName, managedObjectModel: model)
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
            container.loadPersistentStores { desc, error in
                if let error = error {
                    fatalError("CoreData in-memory failed: \(error)")
                }
            }
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true
            self._customContainer = container
        } else {
            self._customContainer = nil
        }
    }

    // internal holder if custom container created in init(useInMemoryStore: true)
    private var _customContainer: NSPersistentContainer?

    // accessor контейнера (поддерживает режим in-memory)
    private var persistentContainer: NSPersistentContainer {
        return _customContainer ?? container
    }

    // MARK: - Public contexts

    /// Основной UI контекст
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    /// Создать background context
    public func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    /// Сохранить контекст, бросает ошибку в случае провала
    public func saveContext(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - API для Codable объектов
    
    /// Атомарно модифицирует массив T, сохранённый под ключом key.
    /// - Если записи нет — передаётся пустой массив.
    /// - modify замыкание выполняется внутри performAndWait у контекста, затем результат сериализуется и сохраняется.
    public func modifyArray<T: Codable>(of type: T.Type, forKey key: String, context: NSManagedObjectContext? = nil, modify: (inout [T]) throws -> Void) throws {
        let ctx = context ?? viewContext
        try ctx.performAndWaitIfNeeded {
            // получаем существующую сущность
            if let obj = try fetchEntity(key: key, context: ctx) {
                // пытаемся декодировать массив
                var array: [T] = []
                if let data = obj.value(forKey: "value") as? Data {
                    array = (try? JSONDecoder().decode([T].self, from: data)) ?? []
                }
                try modify(&array)
                let newData = try JSONEncoder().encode(array)
                obj.setValue(newData, forKey: "value")
                obj.setValue(Date(), forKey: "createdAt")
            } else {
                // создаём новую сущность и применяем изменения к пустому массиву
                var array: [T] = []
                try modify(&array)
                let entityDesc = NSEntityDescription.entity(forEntityName: "KeyValue", in: ctx)!
                let newObj = NSManagedObject(entity: entityDesc, insertInto: ctx)
                newObj.setValue(key, forKey: "key")
                newObj.setValue(String(describing: T.self), forKey: "type")
                newObj.setValue(try JSONEncoder().encode(array), forKey: "value")
                newObj.setValue(Date(), forKey: "createdAt")
            }
            if ctx.hasChanges { try ctx.save() }
        }
    }

    /// Сохранить объект T: Codable под ключом key.
    /// Если запись с таким ключом уже существует — она будет перезаписана.
    /// - Parameters:
    ///   - object: объект Codable
    ///   - key: строковый ключ (аналог UserDefaults key)
    ///   - typeName: опционально — имя типа (для отладки, категоризации)
    ///   - context: можно передать свой контекст, иначе используется viewContext
    public func save<T: Codable>(_ object: T, forKey key: String, typeName: String? = nil, context: NSManagedObjectContext? = nil) throws {
        let ctx = context ?? viewContext
        try ctx.performAndWaitIfNeeded {
            let data = try JSONEncoder().encode(object)
            // попытка найти существующий объект
            if let existing = try self.fetchEntity(key: key, context: ctx) {
                existing.setValue(data, forKey: "value")
                existing.setValue(typeName ?? String(describing: T.self), forKey: "type")
                existing.setValue(Date(), forKey: "createdAt")
            } else {
                let entityDesc = NSEntityDescription.entity(forEntityName: "KeyValue", in: ctx)!
                let obj = NSManagedObject(entity: entityDesc, insertInto: ctx)
                obj.setValue(key, forKey: "key")
                obj.setValue(data, forKey: "value")
                obj.setValue(typeName ?? String(describing: T.self), forKey: "type")
                obj.setValue(Date(), forKey: "createdAt")
            }
            if ctx.hasChanges { try ctx.save() }
        }
    }

    /// Загрузить объект T: Codable по ключу. Возвращает nil если нет данных или декодирование не удалось.
    public func load<T: Codable>(_ type: T.Type, forKey key: String, context: NSManagedObjectContext? = nil) throws -> T? {
        let ctx = context ?? viewContext
        return try ctx.performAndWaitIfNeeded {
            guard let obj = try fetchEntity(key: key, context: ctx),
                  let data = obj.value(forKey: "value") as? Data else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    /// Удалить запись по ключу (если есть)
    public func remove(forKey key: String, context: NSManagedObjectContext? = nil) throws {
        let ctx = context ?? viewContext
        try ctx.performAndWaitIfNeeded {
            if let obj = try fetchEntity(key: key, context: ctx) {
                ctx.delete(obj)
                if ctx.hasChanges { try ctx.save() }
            }
        }
    }

    /// Загрузить все ключи (meta-информация)
    public func allKeys(context: NSManagedObjectContext? = nil) throws -> [String] {
        let ctx = context ?? viewContext
        return try ctx.performAndWaitIfNeeded {
            let req = NSFetchRequest<NSManagedObject>(entityName: "KeyValue")
            req.propertiesToFetch = ["key"]
            req.resultType = .managedObjectResultType
            let results = try ctx.fetch(req)
            return results.compactMap { $0.value(forKey: "key") as? String }
        }
    }

    /// Загрузить все объекты типа T (попытка декодировать все записи и выбрать те, которые декодируются как T)
    /// Это удобный метод, но потенциально дорогостоящий на больших наборах.
    public func loadAll<T: Codable>(_ type: T.Type, context: NSManagedObjectContext? = nil) throws -> [T] {
        let ctx = context ?? viewContext
        return try ctx.performAndWaitIfNeeded {
            let req = NSFetchRequest<NSManagedObject>(entityName: "KeyValue")
            let results = try ctx.fetch(req)
            var out: [T] = []
            for mo in results {
                if let data = mo.value(forKey: "value") as? Data {
                    if let decoded = try? JSONDecoder().decode(T.self, from: data) {
                        out.append(decoded)
                    }
                }
            }
            return out
        }
    }

    /// Найти записи по префиксу ключа (например "chat_\(orderId)_") — удобно для группировки
    public func keys(prefix: String, context: NSManagedObjectContext? = nil) throws -> [String] {
        let ctx = context ?? viewContext
        return try ctx.performAndWaitIfNeeded {
            let req = NSFetchRequest<NSManagedObject>(entityName: "KeyValue")
            req.predicate = NSPredicate(format: "key BEGINSWITH %@", prefix)
            let results = try ctx.fetch(req)
            return results.compactMap { $0.value(forKey: "key") as? String }
        }
    }

    // =====================
    // MARK: - Внутренние вспомогательные функции
    // =====================

    /// Программно создаём NSManagedObjectModel: Entity "KeyValue" с полями:
    /// - key: String (уникальный)
    /// - value: Binary Data
    /// - type: String (optional)
    /// - createdAt: Date
    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Entity
        let entity = NSEntityDescription()
        entity.name = "KeyValue"
        entity.managedObjectClassName = "NSManagedObject"

        // attributes
        let keyAttr = NSAttributeDescription()
        keyAttr.name = "key"
        keyAttr.attributeType = .stringAttributeType
        keyAttr.isOptional = false

        let valueAttr = NSAttributeDescription()
        valueAttr.name = "value"
        valueAttr.attributeType = .binaryDataAttributeType
        valueAttr.isOptional = false
        valueAttr.allowsExternalBinaryDataStorage = true

        let typeAttr = NSAttributeDescription()
        typeAttr.name = "type"
        typeAttr.attributeType = .stringAttributeType
        typeAttr.isOptional = true

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false

        entity.properties = [keyAttr, valueAttr, typeAttr, createdAtAttr]

        // unique constraint по key — предотвращает дубликаты
        entity.uniquenessConstraints = [["key"]]

        model.entities = [entity]
        return model
    }

    /// Получить существующий NSManagedObject по ключу (если есть)
    private func fetchEntity(key: String, context: NSManagedObjectContext) throws -> NSManagedObject? {
        let req = NSFetchRequest<NSManagedObject>(entityName: "KeyValue")
        req.predicate = NSPredicate(format: "key == %@", key)
        req.fetchLimit = 1
        let results = try context.fetch(req)
        return results.first
    }
}

// =====================
// MARK: - NSManagedObjectContext concurrency helper
// =====================

private extension NSManagedObjectContext {
    /// Выполнить блок безопасно в зависимости от типа контекста.
    /// Если контекст main-queue — выполнит синхронно; если background — выполнит performAndWait.
    func performAndWaitIfNeeded<T>(_ block: () throws -> T) rethrows -> T {
        if concurrencyType == .mainQueueConcurrencyType {
            return try block()
        } else {
            var result: Result<T, Error>!
            self.performAndWait {
                do {
                    let v = try block()
                    result = .success(v)
                } catch {
                    result = .failure(error)
                }
            }
            switch result! {
            case .success(let v): return v
            case .failure(let e): return e
            }
        }
    }
}
