//
//  MachineModel.swift
//  Nesicofe
//
//  Created by dev on 24/09/2025.
//
import CoreLocation

struct MachineModel: Codable, Equatable, Hashable {
    let id: Int
    let title: String
    let imageName: String
    var coordinate: CoordinateTransformation
    let menu: [DrinkModel]
}
