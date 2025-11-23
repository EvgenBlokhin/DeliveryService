//
//  CoordinateTransformation.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import CoreLocation

struct Coordinate: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    // Для удобного преобразования в CLLocationCoordinate2D и обратно
    var clLocationCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    init(_ lat: Double, _ lon: Double) {
        self.latitude = lat
        self.longitude = lon
    }
}
