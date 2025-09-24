//
//  Coordinate.swift
//  Nesicofe
//
//  Created by dev on 29/08/2025.
//
import CoreLocation

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    var clLocationCoordinate2D: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    init(latitude: Double, longitude: Double) { self.latitude = latitude; self.longitude = longitude }
    init(_ coord: CLLocationCoordinate2D) { self.latitude = coord.latitude; self.longitude = coord.longitude }
}
