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
    var coordinate: CoordinateTransformation
}
