//
//  MapViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

import Foundation
import Combine
import UIKit

final class MapViewModel: ObservableObject {
    @Published private(set) var state: MapData?
    @Published private(set) var annotation: CustomPointAnnotation?
    
    private let mapService: MapService
    private let locationService: UserLocationService
    private var cancellables = Set<AnyCancellable>()
    
    var onOpenMachine: ((MachineModel) -> Void)?
    var onOpenChat: (() -> Void)?
    
    init(service: MapService, locationService: UserLocationService) {
        self.mapService = service
        self.locationService = locationService
        
        bindLocationUpdates()
        locationService.requestAccess()
        Task {
            await loadMapData()
        }
    }
    
    private func bindLocationUpdates() {
        // Подписываемся на координаты
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coord in
                guard let self = self else { return }
                // Обновляем центр и адрес в UI через state
                var address = self.locationService.currentAddress
                if address.isEmpty {
                    address = AppConstants.defaultAddress
                }
                let addrModel = AddressModel(title: address, coordinate: coord)
                
                self.state = MapData(
                    address: address,
                    center: coord,
                    machines: self.state?.machines ?? [],
                    couriers: self.state?.couriers ?? [],
                    selectedAddress: addrModel,
                    annotations: self.state?.annotations ?? [],
                    showChatButton: self.state?.showChatButton ?? false
                )
            }
            .store(in: &cancellables)
        
        // Подписываемся на адрес
        locationService.addressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] address in
                guard let self = self else { return }
                // Обновляем адрес в state
                let center = self.locationService.currentCenter
                let addrModel = AddressModel(title: address, coordinate: center)
                
                self.state = MapData(
                    address: address,
                    center: center,
                    machines: self.state?.machines ?? [],
                    couriers: self.state?.couriers ?? [],
                    selectedAddress: addrModel,
                    annotations: self.state?.annotations ?? [],
                    showChatButton: self.state?.showChatButton ?? false
                )
            }
            .store(in: &cancellables)
    }
    
    func loadMapData() async {
        // Локальные стартовые значения
        let initialAddress = locationService.currentAddress.isEmpty
            ? AppConstants.defaultAddress
            : locationService.currentAddress
        let initialCenter = locationService.currentCenter
        let addressModel = AddressModel(title: initialAddress, coordinate: initialCenter)
        
        do {
            let machines = try await mapService.fetchMachines()
            let couriers = try await mapService.fetchCourier()
            var annotations: [MapAnnotation] = []
            annotations.append(contentsOf: machines.map { .machine($0) })
            annotations.append(contentsOf: couriers.map { .courier($0) })
            annotations.append(.address(addressModel))
            
            let newState = MapData(
                address: initialAddress,
                center: initialCenter,
                machines: machines,
                couriers: couriers,
                selectedAddress: addressModel,
                annotations: annotations,
                showChatButton: false
            )
            
            await MainActor.run {
                self.state = newState
            }
        } catch {
            // При ошибке — обновляем только центр/адрес
            await MainActor.run {
                self.state?.address = initialAddress
                self.state?.center = initialCenter
                self.state?.selectedAddress = addressModel
                rebuildAnnotations()
            }
        }
    }
    
    private func rebuildAnnotations() {
        guard let s = state else { return }
        var newAnnotations: [MapAnnotation] = []
        newAnnotations.append(contentsOf: s.machines.map { .machine($0) })
        newAnnotations.append(contentsOf: s.couriers.map { .courier($0) })
        if let addr = s.selectedAddress {
            newAnnotations.append(.address(addr))
        }
        state?.annotations = newAnnotations
    }
    
    @MainActor
    func filterMachines(byCoffeeName coffeeName: String) {
        let term = coffeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            rebuildAnnotations()
            return
        }
        let normalized = term.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let filtered = state?.machines.filter { machine in
            machine.menu.contains { drink in
                drink.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(normalized)
            }
        } ?? []
        var newAnn: [MapAnnotation] = filtered.map { .machine($0) }
        newAnn.append(contentsOf: state?.couriers.map { .courier($0) } ?? [])
        if let addr = state?.selectedAddress {
            newAnn.append(.address(addr))
        }
        state?.annotations = newAnn
    }
    
    func setManualAddress(_ text: String, completion: @escaping (Result<(Coordinate, String), Error>) -> Void) {
        locationService.setManualAddress(text) { [weak self] result in
            switch result {
            case .success((let coord, let address)):
                DispatchQueue.main.async {
                    let addrModel = AddressModel(title: address, coordinate: coord)
                    self?.state?.center = coord
                    self?.state?.address = address
                    self?.state?.selectedAddress = addrModel
                    self?.rebuildAnnotations()
                }
                completion(.success((coord, address)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func selectAnnotation(_ annotation: MapAnnotation) {
        switch annotation {
        case .machine(let model):
            onOpenMachine?(model)
        case .courier:
            onOpenChat?()
        case .address(let a):
            // можно обновить selectedAddress
            state?.selectedAddress = a
        }
    }
}
