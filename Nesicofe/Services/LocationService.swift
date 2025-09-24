//
//  Untitled.swift
//  Nesicofe
//
//  Created by dev on 19/08/2025.
//


import CoreLocation
import UIKit

protocol LocationServiceDelegate: AnyObject {
    func locationService(_ service: LocationService, didUpdateLocation location: CLLocation)
    func locationServiceDidChangeAuthorization(_ service: LocationService, status: CLAuthorizationStatus)
}

final class LocationService: NSObject, CLLocationManagerDelegate{
    static let shared = LocationService() // singleton (можно убрать, если не нужен)

    private let locationManager = CLLocationManager()
    weak var delegate: LocationServiceDelegate?
    private var onUpdate: ((CLLocation) -> Void)?
    //private var authorizationChangeHandler: ((CLAuthorizationStatus) -> Void)?
    
    var currentAuthorizationStatus: CLAuthorizationStatus {
           return locationManager.authorizationStatus
       }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation(_ callback: @escaping (CLLocation) -> Void) {
        self.onUpdate = callback
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        onUpdate = nil
    }
    
    func handleAuthorizationStatus() -> Bool {
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            print("Разрешение еще не запрашивалось - запрашиваем")
            requestAuthorization()
            return false
            
        case .denied, .restricted:
            print ("Доступ запрещен пользователем")
            showSettingsAlert()
            return false
            
        case .authorizedWhenInUse, .authorizedAlways:
            print ("Все уже разрешено")
            return true
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Показ alert'а для перехода в настройки
        private func showSettingsAlert() {
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Геолокация отключена",
                    message: "Пожалуйста, включите геолокацию в настройках для работы приложения",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Настройки", style: .default) { _ in
                    self.openSettings()
                })
                
                alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                
                // Показываем alert на текущем окне
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(alert, animated: true)
                }
            }
        }
        
        private func openSettings() {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }

// MARK: - CLLocationManagerDelegate

extension LocationService {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        delegate?.locationService(self, didUpdateLocation: location)
        onUpdate?(location)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        delegate?.locationServiceDidChangeAuthorization(self, status: manager.authorizationStatus)
        //handleAuthorizationStatus(manager.authorizationStatus)
    }
}


