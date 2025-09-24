//
//  MapViewModel.swift
//  Nesicofe
//
//  Created by dev on 27/08/2025.
//

import CoreLocation

final class MapViewModel: ObservableObject {
    @Published private(set) var state: MapViewState
    
    private let machines: MockService
    private let location: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    // Навигационные события (координатору)
    var onOpenMachine: ((Int) -> Void)?
    var onOpenChat: ((String) -> Void)?
    
    init(machines: MockService, location: LocationService) {
        self.machines = machines
        self.location = location
        
        self.state = MapViewState(
            address: location.currentAddress.isEmpty ? AppConstants.defaultAddress : location.currentAddress,
            center: location.currentCenter,
            annotations: [],
            showChatButton: true
        )
        
        bindLocation()
        requestAccess()
    }
    
    private func bindLocation() {
        location.onLocationUpdated = { [weak self] coord, address in
            guard let self = self else { return }
            self.state.center = coord
            self.state.address = address.isEmpty ? AppConstants.defaultAddress : address
        }
    }
    
    // Восстановление/обновление списка машин (public — можно вызывать из VC)
    func loadMachines() {
            let machineAnnotations = machines.list.map { MapAnnotation.machine($0) }
            let couriers = state.annotations.filter { $0.isCourier }
            DispatchQueue.main.async {
                self.state.annotations = machineAnnotations + couriers
            }
        }

    
    func requestAccess() {
        location.requestAccess()
    }
    
    func centerOnCurrent() {
        location.centerOnCurrent()
    }
    
    // Установка адреса вручную — передаём результат наружу (совместимо с прежним контрактом)
        func setManualAddress(_ text: String, completion: @escaping (Result<(CLLocationCoordinate2D, String), Error>) -> Void) {
            location.setManualAddress(text) { [weak self] result in
                switch result {
                case .success(let (coord, address)):
                    DispatchQueue.main.async {
                        self?.state.center = coord
                        self?.state.address = address
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
                onOpenMachine?(model.id)
            case .courier:
                // можно прокинуть открытие чата или другое действие
                onOpenChat?("courier")
            }
        }
    
    func showCourier(at coordinate: CourierModel) {
            DispatchQueue.main.async {
                // удаляем старых курьеров (если хотим один)
                self.state.annotations.removeAll { annotation in
                    if case .courier = annotation { return true } else { return false }
                }
                self.state.annotations.append(.courier(coordinate))
                self.state.showChatButton = true
            }
        }
    }
