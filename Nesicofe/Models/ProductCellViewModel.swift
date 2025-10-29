//
//  ProductCellViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

struct ProductCellViewModel {
    let id: Int
    let name: String
    let priceText: String
    let image: UIImage?
    let sugarLevel: Int
    let countDrink: Int

    // Коллбеки: ячейка вызывает → контроллер → VM/сервис
    var onSugarChanged: ((Int) -> Void)?
    var onCountChanged: ((Int) -> Void)?
    var onProductRemove: (() -> Void)?

    // Init для корзины
    init(item: CartItem) {
        self.id = item.coffee.id
        self.name = item.coffee.name
        self.priceText = "\(Int(item.coffee.price))₽"
        self.image = UIImage(named: item.coffee.imageName)
        self.sugarLevel = item.sugar
        self.countDrink = item.count
    }

    // Init для деталей
    init(model: DrinkModel, sugar: Int, count: Int) {
        self.id = model.id
        self.name = model.name
        self.priceText = "\(Int(model.price))₽"
        self.image = UIImage(named: model.imageName)
        self.sugarLevel = sugar
        self.countDrink = count
    }
}
