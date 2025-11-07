//
//  CartService.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class CartService {
    @Published private(set) var sections: [CartSection] = []
    private(set) var activeMachineId: Int?

    var onCartUpdate: (() -> Void)?

    //  Обновить количество (если 0 → удалить; если нет секции → создать)
    func updateCount(for coffee: DrinkModel,
                     value: Int,
                     sugar: Int,
                     machineId: Int,
                     address: String) {
        if let secIdx = sections.firstIndex(where: { $0.machineId == machineId }) {
            // секция найдена
            if let itemIdx = sections[secIdx].items.firstIndex(where: { $0.coffee.id == coffee.id }) {
                if value <= 0 {
                    // удаляем товар
                    sections[secIdx].items.remove(at: itemIdx)
                    cleanupIfEmpty(machineId: machineId)
                } else {
                    // обновляем товар
                    sections[secIdx].items[itemIdx].count = value
                    sections[secIdx].items[itemIdx].sugar = min(3, max(0, sugar))
                }
            } else if value > 0 {
                // добавляем новый товар в существующую секцию
                sections[secIdx].items.append(CartItem(coffee: coffee,
                                                       sugar: min(3, max(0, sugar)),
                                                       count: value))
            }
        } else if value > 0 {
            // секции ещё нет → создаём новую
            let newSection = CartSection(
                machineId: machineId,
                address: address,
                items: [CartItem(coffee: coffee,
                                 sugar: min(3, max(0, sugar)),
                                 count: value)]
            )
            sections.append(newSection)
            activeMachineId = machineId
        }

        onCartUpdate?()
    }
    
    // Изменение активной для заказа машины
    func updateSection(machineId: Int) {
        activeMachineId = machineId
    }

    //  Обновить сахар отдельно
    func updateSugar(for coffeeId: Int, value: Int, machineId: Int) {
        guard let secIdx = sections.firstIndex(where: { $0.machineId == machineId }),
              let itemIdx = sections[secIdx].items.firstIndex(where: { $0.coffee.id == coffeeId })
        else { return }

        sections[secIdx].items[itemIdx].sugar = min(3, max(0, value))
        onCartUpdate?()
    }

    // Завершить заказ
    func completeOrder() {
        if let active = activeMachineId {
            sections.removeAll { $0.machineId == active }
            activeMachineId = sections.first?.machineId
            onCartUpdate?()
        }
    }

    // Сумма по секции
    func total(for machineId: Int) -> Double {
        sections.first(where: { $0.machineId == machineId })?
            .items.reduce(0) { $0 + ($1.coffee.price * Double($1.count)) } ?? 0
    }

    //  Private
    private func cleanupIfEmpty(machineId: Int) {
        if let secIdx = sections.firstIndex(where: { $0.machineId == machineId }),
           sections[secIdx].items.isEmpty {
            sections.remove(at: secIdx)
            if activeMachineId == machineId {
                activeMachineId = sections.first?.machineId
            }
        }
    }
}
