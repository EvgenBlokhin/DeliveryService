//
//  BufferStorage.swift
//  Nesicofe
//
//  Created by dev on 06/11/2025.
//
import Foundation
import CoreData

protocol BufferStorage {
    func save<T: Codable>(_ array: [T], forKey key: String) throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func remove(forKey key: String) throws
}

final class CoreDataBufferStorage: BufferStorage {
    
    private let core: CoreDataStorage
    
    init(core: CoreDataStorage) {
        self.core = core
    }


    func save<T: Codable>(_ array: [T], forKey key: String) throws {
        // Выполняем запись в background context атомарно
        let ctx = core.newBackgroundContext()
        // используем save (перезапись)
        try core.save(array, forKey: key, context: ctx)
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        // Чтение тоже на background context — безопасно и не блокирует UI
        let ctx = core.newBackgroundContext()
        return try core.load(type, forKey: key, context: ctx)
    }

    func remove(forKey key: String) throws {
        let ctx = core.newBackgroundContext()
        try core.remove(forKey: key, context: ctx)
    }
}
