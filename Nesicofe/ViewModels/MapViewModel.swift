//
//  MapViewModel.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

import UIKit
import Combine
@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var state: MapData? = nil
    @Published private(set) var annotation: CustomPointAnnotation
    private let mapService: MapService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    // Навигационные события (координатору)
    var onOpenMachine: ((MachineModel) -> Void)?
    var onOpenChat: ((Int) -> Void)?
    
    init(service: MapService, location: LocationService) {
        self.mapService = service
        self.locationService = location
        bindLocation()
        requestAccess()
        Task.detached {
            await self.loadMapData()
        }
    }
    
    func requestAccess() {
        locationService.requestAccess()
    }
    
    func centerOnCurrent() {
        locationService.centerOnCurrent()
    }
    
    
    private func bindLocation() {
        locationService.onLocationUpdated = { [weak self] coord, address in
            guard let self = self else { return }
            self.state?.center = coord
            self.state?.address = address.isEmpty ? AppConstants.defaultAddress : address
        }
    }
    
    func updateAnnotations(_ list: [MapAnnotation]) {
        let annotation = CustomPointAnnotation()
        
        for ann in list {
            annotation.coordinate = ann.coordinate.clLocationCoordinate
            annotation.title = ann.title
            annotation.id = ann.id
            annotation.isCourier = ann.isCourier
            
            self.annotation = annotation
        }
    }
    
    // Восстановление/обновление списка машин (public — можно вызывать из VC)
    
    func loadMapData() async {
        // Временные контейнеры для новых значений
        var newMachines: [MachineModel] = []
        var newCouriers: [CourierModel] = []
        
        // Получаем адрес/центр из LocationService (локальная информация, без ожидания сети)
        let location = locationService.currentAddress.isEmpty ? AppConstants.defaultAddress : locationService.currentAddress
        let center = locationService.currentCenter
        let addressModel = AddressModel(title: location, coordinate: center)
        
        do {
            // Попытка загрузить данные с сервера
            newMachines = try await mapService.fetchMachines()
            newCouriers = try await mapService.fetchCourier()
            
            // Построим аннотации из свежих данных: машины + курьеры + адрес (если нужен)
            var annotations: [MapAnnotation] = []
            annotations.append(contentsOf: newMachines.map { MapAnnotation.machine($0) })
            annotations.append(contentsOf: newCouriers.map { MapAnnotation.courier($0) })
            // Вставляем адрес в конец (или в начало — по UX)
            annotations.append(.address(addressModel))
            
            // Обновляем state целиком — source of truth: machines/couriers/selectedAddress/annotations
            state = .init(
                address: location,
                center: center,
                machines: newMachines,
                couriers: newCouriers,
                selectedAddress: addressModel,
                annotations: annotations,
                showChatButton: false
            )
            
        } catch {
            // Если произошла ошибка — логируем и не затираем текущее state (fallback).
            // Можно также показать UI-ошибку, или очистить только specific fields.
            //log("Loaded \(newMachines.count) machines, \(newCouriers.count) couriers")
            
            // Вариант поведения: оставить старый state, но обновить центр/адрес (локальная info)
            state?.address = location
            state?.center = center
            // Если у тебя есть selectedAddress логика — обновляем её
            state?.selectedAddress = addressModel
            // Альтернатива: очистить машины, если нужно:
            // state.machines = []
            // rebuild annotations, например:
            rebuildAnnotations()
        }
    }
    
    @MainActor
    private func rebuildAnnotations() {
        var annotations: [MapAnnotation] = []
        annotations.append(contentsOf: state.machines.map { MapAnnotation.machine($0) })
        annotations.append(contentsOf: state.couriers.map { MapAnnotation.courier($0) })
        if let addr = state.selectedAddress {
            annotations.append(.address(addr))
        }
        state.annotations = annotations
    }
    
    @MainActor
    func filterMachines(byCoffeeName coffeeName: String) {
        let term = coffeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            rebuildAnnotations()
            return
        }

        let normalized = term.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let filteredMachines = state.machines.filter { machine in
            machine.menu.contains { drink in
                drink.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(normalized)
            }
        }

        // Собираем итоговые аннотации: отфильтрованные машины + курьеры + адрес
        var annotations: [MapAnnotation] = filteredMachines.map { MapAnnotation.machine($0) }
        annotations.append(contentsOf: state.couriers.map { MapAnnotation.courier($0) })
        if let address = state.selectedAddress { annotations.append(.address(address)) }

        state.annotations = annotations
    }
    
    // Установка адреса вручную — передаём результат наружу (совместимо с прежним контрактом)
    func setManualAddress(_ text: String, completion: @escaping (Result<(CoordinateTransformation, String), Error>) -> Void) {
        locationService.setManualAddress(text) { [weak self] result in
                switch result {
                case .success(let (coordinate, address)):
                    DispatchQueue.global().async {
                        self?.state.center = coordinate
                        self?.state.address = address
                        self?.state.annotations.append(.address(AddressModel(title: address, coordinate: coordinate)))
                    }
                    completion(.success((coordinate, address)))
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
                // можно прокинуть открытие чата или другое действие
                print("onOpenChat?")
            case .address(let address):
                print("Текущий адрес \(address)")
            }
        }
    
//    func showCourier(at coordinate: CourierModel) {
//            DispatchQueue.main.async {
//                // удаляем старых курьеров (если хотим один)
//                self.state.annotations.removeAll { annotation in
//                    if case .courier = annotation { return true } else { return false }
//                }
//                self.state.annotations.append(.courier(coordinate))
//                self.state.showChatButton = true
//            }
//        }
    }
