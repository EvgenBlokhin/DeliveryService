//
//  CourierModel.swift
//  Nesicofe
//
//  Created by dev on 24/09/2025.
//

import CoreLocation

struct CourierModel: Codable, Hashable {
    var id: Int
    var name: String
    let lat: Double
    let lon: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}
