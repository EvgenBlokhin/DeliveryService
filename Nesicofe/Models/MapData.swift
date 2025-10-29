//
//  MapData.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import Foundation
import CoreLocation

struct MapData {
    var address: String
    var center: CoordinateTransformation
    
    // Источники правды внутри state:
    var machines: [MachineModel]      // полный список машин (на сервере)
    var couriers: [CourierModel]      // текущие курьеры (realtime)
    var selectedAddress: AddressModel? // выбранный адрес (или nil)
    
    // Выводимое поле для MapView (аннотации строятся из sources выше)
    var annotations: [MapAnnotation]
    
    var showChatButton: Bool
    
    init(address: String,
         center: CoordinateTransformation,
    machines: [MachineModel] = [],
    couriers: [CourierModel] = [],
    selectedAddress: AddressModel? = nil,
    annotations: [MapAnnotation],
    showChatButton: Bool = false) {
        self.address = address
        self.center = center
        self.machines = machines
        self.couriers = couriers
        self.selectedAddress = selectedAddress
        self.annotations = annotations
        self.showChatButton = showChatButton
    }
}

