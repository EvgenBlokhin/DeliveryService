import Foundation
import CoreLocation
import Combine

final class UserLocationService: NSObject {
    // MARK: - Публичные свойства (внутреннее состояние)
    private(set) var currentAddress: String = AppConstants.defaultAddress
    private(set) var currentCenter: Coordinate = AppConstants.defaultCoord
    
    // Паблишеры для координат (GPS) — чтобы другие части могли подписываться
    let locationPublisher = PassthroughSubject<Coordinate, Never>()
    // Паблишер адреса
    let addressPublisher = PassthroughSubject<String, Never>()
    
    // MARK: - Зависимости
    private let locationManager: CLLocationManager
    private let geocoder: CLGeocoder
    private let authService: AuthService
    private var webSocket: WebSocketService?
    
    // MARK: - Внутренние
    private var cancellables = Set<AnyCancellable>()
    @Published private var isCourier: Bool = false
    
    // Контроль частоты отправки на сервер
    private var lastSentLocation: CLLocation?
    private let sendDistanceThreshold: CLLocationDistance = 30
    private let sendThrottleInterval: TimeInterval = 1.0
    
    // Контроль частоты геокодирования
    private var lastGeocodeTime: Date?
    private let minGeocodeInterval: TimeInterval = 5
    
    // MARK: - Init
    init(authService: AuthService, defaultAddress: String, defaultCoord: Coordinate) {
        self.authService = authService
        self.locationManager = CLLocationManager()
        self.geocoder = CLGeocoder()
        
        self.currentAddress = defaultAddress
        self.currentCenter = defaultCoord
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = sendDistanceThreshold  // обновлять при смещении >= 30 метров
        
        // Подписка на роль
        authService.$currentUser
            .map { $0?.role == .courier }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] courier in
                self?.isCourier = courier
            }
            .store(in: &cancellables)
        
        // Подписка на поток координат
        locationPublisher
            .combineLatest($isCourier)
            .filter { _, isCourier in
                // Даже если не курьер — можно публиковать локально, но отправлять только когда isCourier == true
                isCourier
            }
            .map { coord, _ in coord }
            .throttle(for: .seconds(sendThrottleInterval), scheduler: DispatchQueue.global(), latest: true)
            .sink { [weak self] coord in
                guard let self = self else { return }
                
                // Отправка на сервер через WebSocket
                let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let shouldSend: Bool
                if let last = self.lastSentLocation {
                    shouldSend = newLoc.distance(from: last) >= self.sendDistanceThreshold
                } else {
                    shouldSend = true
                }
                if shouldSend {
                    self.lastSentLocation = newLoc
                    
                    struct Payload: Encodable {
                        let lat: Double
                        let lon: Double
                        let timestamp: TimeInterval
                    }
                    let payload = Payload(lat: coord.latitude, lon: coord.longitude, timestamp: Date().timeIntervalSince1970)
                    self.webSocket?.sendEnvelope(type: .updateCourierLocation, orderId: nil, payload: payload)
                }
            }
            .store(in: &cancellables)
    }
    
    
    // MARK: - Публичные методы
    func setWebSocket(_ socket: WebSocketService) {
        self.webSocket = socket
    }
    
    func requestAccess() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // можно отправить callback / показать UI как-то
            break
        @unknown default:
            break
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    func centerOnCurrent() {
        locationManager.requestLocation()
    }
    
    func setManualAddress(_ text: String, completion: @escaping (Result<(Coordinate, String), Error>) -> Void) {
        geocoder.cancelGeocode()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "geo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Пустой адрес"])))
            }
            return
        }
        geocoder.geocodeAddressString(trimmed) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let pm = placemarks?.first, let loc = pm.location else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "geo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Адрес не найден"])))
                }
                return
            }
            let coord = Coordinate(loc.coordinate)
            let address = [
                pm.locality, pm.thoroughfare, pm.subThoroughfare
            ].compactMap { $0 }.joined(separator: ", ")
            let finalAddress = address.isEmpty ? trimmed : address
            
            // обновляем внутренние свойства
            self.currentCenter = coord
            self.currentAddress = finalAddress
            
            // оповещаем через publisher
            self.locationPublisher.send(coord)
            self.addressPublisher.send(finalAddress)
            
            DispatchQueue.main.async {
                completion(.success((coord, finalAddress)))
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension UserLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        // Можно оповестить внешний код о статусе
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = Coordinate(loc.coordinate)
        
        // Публикуем каждый раз, когда геопозиция реально обновилась (>= 30м фильтр уже на distanceFilter)
        locationPublisher.send(coord)
        
        // Геокодирование, но не слишком часто
        let now = Date()
        if let last = lastGeocodeTime, now.timeIntervalSince(last) < minGeocodeInterval {
            return
        }
        lastGeocodeTime = now
        
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
            guard let self = self else { return }
            guard let pm = placemarks?.first else { return }
            
            // CLPlacemark.location может отличаться от входной точки
            if let placeLocation = pm.location {
                let placeCoord = Coordinate(placeLocation.coordinate)
                self.currentCenter = placeCoord
            } else {
                self.currentCenter = coord
            }
            
            let addressParts = [pm.locality, pm.thoroughfare, pm.subThoroughfare]
            let address = addressParts.compactMap { $0 }.joined(separator: ", ")
            if !address.isEmpty {
                self.currentAddress = address
                self.addressPublisher.send(address)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}
