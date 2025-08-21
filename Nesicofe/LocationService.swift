//
//  Untitled.swift
//  Nesicofe
//
//  Created by dev on 19/08/2025.
//

import SwiftUI
import CoreLocation
import MapKit

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    
    private var mapView: MapViewController?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization() // запрос разрешения
        manager.startUpdatingLocation()
    }
}
// MARK: - CLLocationManagerDelegate

extension LocationService {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
            guard let location = mapView?.showUserLocation() else { return }
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            
            // Центрируем карту на пользователе только при первом запуске
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1500,
                longitudinalMeters: 1500
            )
            guard let map = mapView?.setRegion(region: region) else { return }
            manager.stopUpdatingLocation() // 👈 чтобы не дергала постоянно
        }
    }
}

