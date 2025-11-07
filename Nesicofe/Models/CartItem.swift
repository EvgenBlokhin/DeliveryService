//
//  CartItem.swift
//  Nesicofe
//
//  Created by dev on 29/09/2025.
//

struct CartItem: Codable, Equatable {
    let coffee: DrinkModel
    var sugar: Int // 1...5
    var count: Int // количество штук
    
    init(coffee: DrinkModel, sugar: Int, count: Int) {
        self.coffee = coffee
        self.sugar = sugar
        self.count = count
    }
}
