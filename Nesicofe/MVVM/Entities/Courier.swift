//
//  CourierModel.swift
//  Nesicofe
//
//  Created by dev on 24/09/2025.
//

import CoreLocation

enum CourierStatus: String, Codable { case available, unavailable }

struct Courier: Codable, Hashable {
    var id: String
    var orderId: String?
    var name: String
    var status: String
    var coordinate: Coordinate?
}
