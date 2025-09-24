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
    let lat: Double
    let lon: Double
    let imageName: String
    let menu: [DrinkModel]
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}
