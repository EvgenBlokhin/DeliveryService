import CoreLocation
import UIKit

protocol AddressProviding: AnyObject {
    var currentAddress: String { get }
    var currentCenter: CoordinateTransformation { get }
}
final class LocationService: NSObject, CLLocationManagerDelegate, AddressProviding {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var currentAddress: String = AppConstants.defaultAddress
    private(set) var currentCenter: CoordinateTransformation = AppConstants.defaultCoord

    var onLocationAuthChanged: ((CLAuthorizationStatus) -> Void)?
    var onLocationUpdated: ((CoordinateTransformation, String) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    
    func requestAccess() {
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            print("Разрешение еще не запрашивалось - запрашиваем")
            locationManager.requestWhenInUseAuthorization()
            
        case .denied, .restricted:
            print ("Доступ запрещен пользователем")
            showSettingsAlert()
            
        case .authorizedWhenInUse, .authorizedAlways:
            print ("Все уже разрешено")

         default:
            break
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
    
    func centerOnCurrent() {
        locationManager.requestLocation()
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

    func setManualAddress(_ text: String, completion: @escaping (Result<(CoordinateTransformation, String), Error>) -> Void) {
        geocoder.geocodeAddressString(text) { [weak self] placemarks, error in
            guard let self else { return }
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let marks = placemarks?.first, let loc = marks.location else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "geo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Адрес не найден"])))
                }
                return
            }
            let coord = CoordinateTransformation(loc.coordinate)
            let address = [marks.locality, marks.thoroughfare, marks.subThoroughfare].compactMap { $0 }.joined(separator: ", ")
            self.currentCenter = coord
            self.currentAddress = address.isEmpty ? text : address
            DispatchQueue.main.async {
                completion(.success((coord, self.currentAddress)))
                self.onLocationUpdated?(coord, self.currentAddress)
            }
        }
    }

    // CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onLocationAuthChanged?(manager.authorizationStatus)
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentCenter = .init(location.coordinate)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let placemarks = placemarks?.first
            let address = [placemarks?.locality, placemarks?.thoroughfare, placemarks?.subThoroughfare].compactMap { $0 }.joined(separator: ", ")
            if !address.isEmpty { self.currentAddress = address }
            DispatchQueue.main.async {
                self.onLocationUpdated?(self.currentCenter, self.currentAddress)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // оставляем дефолт
        print("Location error:", error)
    }
}
