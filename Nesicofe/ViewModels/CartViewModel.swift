//
//  CartViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class CartViewModel: CartViewModelProtocol  {
    private let cartService: CartService
    private let ordersService: OrdersService
    private let authService: AuthService
    private weak var addressProvider: AddressProviding? //уточнить

    // Outputs
    //var onUpdated: (() -> Void)?
    var onNeedAddress: (() -> Void)?
    var onCourierIsCustomerRequired: (() -> Void)?
    var onOrderCreated: ((OrderModel) -> Void)?
    var onError: ((String) -> Void)?

    init(cart: CartService,
         orders: OrdersService,
         auth: AuthService, address: AddressProviding ) {
        self.cartService = cart
        self.ordersService = orders
        self.authService = auth
        self.addressProvider = address
        self.cartListener()

    }

    // Outputs для View

    var onUpdated: (() -> Void )?
    
    var sections: [CartSection] { cartService.sections }

    var total: Double {
        guard let activeId = cartService.activeMachineId else { return 0 }
        return cartService.total(for: activeId)
    }

    var activeMachineId: Int? { cartService.activeMachineId }

    private func cartListener() {
        self.cartService.onCartUpdate = { [weak self] in
            self?.onUpdated?()
        }
    }
    
    func productCellViewModel(for indexPath: IndexPath) -> ProductCellViewModel {
        
        let section = cartService.sections[indexPath.section]
        let item =  section.items[indexPath.row]
        
        var cellViewModel = ProductCellViewModel(item: item)
        
        cellViewModel.onCountChanged = { [weak self] newValue in
            self?.addDrink(indexPath.row, value: newValue, machineId: section.machineId)
        }
        cellViewModel.onSugarChanged = { [weak self] newValue in
            self?.addSugar(indexPath.row, value: newValue, machineId: section.machineId)
        }
        cellViewModel.onProductRemove = { [weak self] in
            self?.removeDrink(indexPath.row, machineId: section.machineId)
        }
        return cellViewModel
    }

    // Actions с товарами
    func removeDrink(_ index: Int, machineId: Int) {
        guard let section = cartService.sections.first(where: { $0.machineId == machineId }) else { return }
        let item = section.items[index]
        cartService.updateCount(for: item.coffee,
                                value: 0,
                                sugar: item.sugar,
                                machineId: machineId,
                                address: section.address)
    }

    func addSugar(_ index: Int, value: Int, machineId: Int) {
        guard let section = cartService.sections.first(where: { $0.machineId == machineId }) else { return }
        let item = section.items[index]
        let coffeeId = item.coffee.id
        cartService.updateSugar(for: coffeeId, value: value, machineId: machineId)
    }

    func addDrink(_ index: Int, value: Int, machineId: Int) {
        guard let section = cartService.sections.first(where: { $0.machineId == machineId }) else { return }
        let item = section.items[index]
        cartService.updateCount(for: item.coffee,
                                value: value,
                                sugar: item.sugar,
                                machineId: machineId,
                                address: section.address)
    }

    // Управление секциями
    func setActiveSection(_ machineId: Int) {
        cartService.updateSection(machineId: machineId)
    }

    // Оформление заказа
    func placeOrder() async {
        guard let user = await authService.currentUser else {
            onError?("Войдите в профиль покупателя")
            return
        }
        guard user.role == "courier"  else {
            onCourierIsCustomerRequired?()
            return
        }
        guard let activeMachineId = cartService.activeMachineId,
              let activeSection = cartService.sections.first(where: { $0.machineId == activeMachineId }) else {
            onError?("Выберите автомат и напитки")
            return
        }

        let address = activeSection.address.isEmpty
        ? (addressProvider?.currentAddress ?? AppConstants.defaultAddress)
            : activeSection.address

        if address == AppConstants.defaultAddress {
            onNeedAddress?()
            return
        }

        if activeSection.items.isEmpty {
            onError?("Корзина пуста")
            return
        }
        do {
            let order = try await ordersService.createOrder(
                fromAddress: user.id,
                toAddress: activeSection.address,
                items: activeSection.items,
                price: 12, contact: ""
            )
            self.cartService.completeOrder()
            self.onOrderCreated?(order)
        } catch {
            self.onError?("\(error)")
            }
        }
    }
