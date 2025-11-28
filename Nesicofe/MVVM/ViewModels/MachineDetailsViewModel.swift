//
//  MachineDetailsViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit
import Combine

protocol CartViewModelProtocol {
    func productCellViewModel(for indexPath: IndexPath) -> ProductCellViewModel
    func addDrink(_ index: Int, value: Int, machineId: Int)
    func addSugar(_ index: Int, value: Int, machineId: Int)
    func removeDrink(_ index: Int, machineId: Int)
}

final class MachineDetailsViewModel: CartViewModelProtocol {
    private let machineItem: MachineModel
    private var cartItem: [CartItem] = []
    private let cartService: CartService
    private var cancellables = Set<AnyCancellable>()

    var onCartUpdated: (() -> Void)?
    var onOpenCart: (() -> Void)?
    var onShowError: ((String) -> Void)?
    
    var numberOfItems: Int { return machineItem.menu.count }

    init(machine: MachineModel, cart: CartService) {
        self.machineItem = machine
        self.cartService = cart
        cartListener()
    }
    
    
    
    private func cartListener() {
        cartService.$sections
            .map { sections -> [CartItem] in
                sections.first(where: { $0.machineId == self.machineItem.id })?.items ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.cartItem = items
                self?.onCartUpdated?()
            }
            .store(in: &cancellables)
    }
    func getMachineName() -> String {
        machineItem.title
    }
    
    func productCellViewModel(for indexPath: IndexPath) -> ProductCellViewModel {
        let machine = machineItem
        let menu = machine.menu[indexPath.row]
        let sugar = sugarLevel(for: menu.id)
        let drink = drinksLevel(for: menu.id)
        
        
        var cellViewModel = ProductCellViewModel(model: menu, sugar: sugar, count: drink)

      
        cellViewModel.onSugarChanged = { [weak self] value in
            self?.addSugar(indexPath.row, value: value, machineId: machine.id)
        }
        
        cellViewModel.onCountChanged = { [weak self] value in
            self?.addDrink(indexPath.row, value: value, machineId: machine.id)
        }
    
        cellViewModel.onProductRemove = { [weak self] in
            self?.removeDrink(indexPath.row, machineId: machine.id)
        }
       
        return cellViewModel
    }
    

    func goToCart() { onOpenCart?() }

    func sugarLevel(for coffeeId: Int) -> Int {
        cartItem.first(where: { $0.coffee.id == coffeeId })?.sugar ?? 0
    }
    func drinksLevel(for coffeeId: Int) -> Int {
        cartItem.first(where: { $0.coffee.id == coffeeId })?.count ?? 0
    }
    
    func addDrink(_ index: Int, value: Int, machineId: Int) {
        let coffee = machineItem.menu[index]
        cartService.updateCount(for: coffee,
                         value: value,
                                sugar: sugarLevel(for: coffee.id),
                         machineId: machineItem.id,
                         address: machineItem.title)
    }
    
    func addSugar(_ index: Int, value: Int, machineId: Int) {
        let coffeeId = machineItem.menu[index].id
        cartService.updateSugar(for: coffeeId, value: value, machineId: machineItem.id)
    }
    
    func removeDrink(_ index: Int, machineId: Int) {
        let coffee = machineItem.menu[index]
        cartService.updateCount(for: coffee,
                         value: 0,
                         sugar: 0,
                         machineId: machineItem.id,
                         address: machineItem.title)
    }

}
