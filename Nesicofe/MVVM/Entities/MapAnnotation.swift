//
//  MapAnnotation.swift
//  Nesicofe
//
//  Created by dev on 29/09/2025.
//

enum MapAnnotation: Equatable {
    
    case machine(MachineModel)
    case courier(CourierModel)
    case address(AddressModel)
    
    var id: Int {
        switch self {
        case .machine(let model): return model.id
        case .courier: return -1
        case .address: return 0
        }
    }
    
    var title: String {
        switch self {
        case .machine(let model): return model.title
        case .courier: return "Курьер"
        case .address(let model): return model.title
            
        }
    }
    
    var coordinate: Coordinate {
        switch self {
        case .machine(let model): return model.coordinate
        case .courier(let coord): return coord.coordinate
        case .address(let model): return model.coordinate
        }
    }
        
        var isCourier: Bool {
            switch self {
            case .courier: return true
            default: return false
            }
        }
    }
