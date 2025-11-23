import Foundation
import CoreLocation
import UIKit
import Combine

final class UserLocationService: NSObject {
    // MARK: - Публичное состояние (UI/другие части приложения читают это)
    @Published private(set) var courierLocation: [Coordinate] = []
    @Published private(set) var currentAddress: String = AppConstants.defaultAddress
    @Published private(set) var currentCenter: Coordinate = AppConstants.defaultCoord

    // колбеки (оставил, как у тебя)
    var onLocationAuthChanged: ((CLAuthorizationStatus) -> Void)?
    var onLocationUserUpdated: ((Coordinate, String) -> Void)?

    // MARK: - Внтренние
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var cancellables = Set<AnyCancellable>()

    private let authService: AuthService

    // поток для координат — публикуем сюда координаты из didUpdateLocations
    private let locationSubject = PassthroughSubject<Coordinate, Never>()

    // флаг роли (внутренний источник истины)
    @Published private var isCourier: Bool = false

    // для уменьшения частоты отправки на сервер
    private var lastSentLocation: CLLocation?
    private let sendDistanceThresholdMeters: CLLocationDistance = 10 // шлём только при смещении >10м
    private let sendThrottleSeconds: TimeInterval = 2.0

    // MARK: - Init
    init(authService: AuthService) {
        self.authService = authService
        super.init()
        locationManager.delegate = self

        // Настройки locationManager
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5 // метры — регулировка исходя из потребностей
        locationManager.pausesLocationUpdatesAutomatically = true
        // Если нужны фоновые обновления, установите allowsBackgroundLocationUpdates = true
        // и проверьте соответствующие Info.plist и политики App Store:
        // locationManager.allowsBackgroundLocationUpdates = true

        // Подписка на роль — единоразово
        authService.$currentUser
            .map { $0?.role == .courier }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isCourier in
                self?.isCourier = isCourier
            }
            .store(in: &cancellables)

        // Pipeline: берем координаты -> фильтруем по роли -> throttle -> отправляем
        locationSubject
            .combineLatest($isCourier)
            .filter { _, isCourier in isCourier }           // только для курьеров
            .map { coord, _ in coord }
            .throttle(for: .seconds(sendThrottleSeconds), scheduler: DispatchQueue.global(), latest: true)
            .sink { [weak self] coord in
                guard let self = self else { return }
                // Обновляем локальное состояние (UI) на main
                DispatchQueue.main.async {
                    self.currentCenter = coord
                    self.courierLocation.append(coord)
                }

                // Решаем — отправлять на сервер или нет (проверяем расстояние)
                let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                if let last = self.lastSentLocation {
                    if newLoc.distance(from: last) >= self.sendDistanceThresholdMeters {
                        self.lastSentLocation = newLoc
                        self.sendLocationToServer(coord)
                    } // иначе — не значительное смещение, пропускаем
                } else {
                    self.lastSentLocation = newLoc
                    self.sendLocationToServer(coord)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API
    func requestAccess() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showSettingsAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        @unknown default:
            break
        }
    }

    func centerOnCurrent() {
        locationManager.requestLocation()
    }

    //MARK: Ручная установка адреса (пользователь ввёл текст)
    func setManualAddress(_ text: String, completion: @escaping (Result<(Coordinate, String), Error>) -> Void) {
        // Отменяем предыдущие запросы (если были)
        geocoder.cancelGeocode()

        // Нормализуем вход
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                let err = NSError(domain: "geo", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Пустой адрес"
                ])
                completion(.failure(err))
            }
            return
        }

        geocoder.geocodeAddressString(trimmed) { [weak self] placemarks, error in
            guard let self = self else { return } // если self освобождён — молча выходим

            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let mark = placemarks?.first, let location = mark.location else {
                DispatchQueue.main.async {
                    completion(.failure(
                        NSError(domain: "geo", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "Адрес не найден"
                        ])
                    ))
                }
                return
            }

            let coord = Coordinate(location.coordinate)
            let address = [
                mark.locality,
                mark.thoroughfare,
                mark.subThoroughfare
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: ", ")

            let finalAddress = address.isEmpty ? trimmed : address

            // все обновления состояния и колбэки — на main
            DispatchQueue.main.async {
                self.currentCenter = coord
                self.currentAddress = finalAddress
                completion(.success((coord, finalAddress)))
                self.onLocationUserUpdated?(coord, finalAddress)
            }
        }
    }

    // MARK: - Helpers
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

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }

    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func sendLocationToServer(_ coord: Coordinate) {
        // Примитивный пример POST — подставь свой URL/авторизацию/формат
        guard let url = URL(string: "https://api.example.com/courier/location") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Если у тебя есть access token — добавь:
        // request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "latitude": coord.latitude,
            "longitude": coord.longitude,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to encode location body:", error)
            return
        }

        // Отправляем в background (не блокируем main)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // обработка ошибок/ретраи — по потребности
                print("sendLocationToServer error:", error)
                return
            }
            // при необходимости — проверка response/data
        }.resume()
    }
}

// MARK: - CLLocationManagerDelegate
extension UserLocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        onLocationAuthChanged?(status)

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Начинаем обновления
            manager.startUpdatingLocation()
        case .denied, .restricted:
            showSettingsAlert()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = Coordinate(loc.coordinate)

        // Публикуем в subject — дальше pipeline решает, отправлять ли на сервер
        locationSubject.send(coord)

        // Reverse geocode — делаем, но дросселим/контролируем: пример — только если адрес пуст или прошло >N сек
        // Здесь простой вариант — попробуем геокодировать, но не блокируем основной поток
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            // Простая защита от частых вызовов: если geocoder занят — пропускаем
            if self.geocoder.isGeocoding {
                return
            }

            self.geocoder.reverseGeocodeLocation(loc) { placemarks, error in
                guard error == nil, let pm = placemarks?.first else { return }
                let address = [
                    pm.locality,
                    pm.thoroughfare,
                    pm.subThoroughfare
                ]
                .compactMap { $0 }
                .joined(separator: ", ")

                if !address.isEmpty {
                    DispatchQueue.main.async {
                        self.currentAddress = address
                        self.currentCenter = coord
                        self.onLocationUserUpdated?(coord, address)
                    }
                } else {
                    // при отсутствии адреса — можно не обновлять currentAddress
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}
