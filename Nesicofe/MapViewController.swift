
import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {
    
    private let mapView = MKMapView()
    private var searchAlert: UIAlertController?
    private var searchTimer: Timer?
    
    // моковые кофемашины
    private var machines: [CoffeeMachine] = [
        CoffeeMachine(
            id: "1",
            name: "Coffee Spot",
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6176),
            rating: 4.7,
            schedule: "08:00–22:00",
            photos: ["coffee1", "coffee2"],
            drinks: [
                Drink(id: "10", name: "Эспрессо", price: 120),
                Drink(id: "11", name: "Капучино", price: 150)
            ],
            reviewsCount: 42
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Карта"
        view.backgroundColor = .systemBackground
        setupMap()
        setupMockMachines()
    }
    
    private func setupMap() {
        mapView.delegate = self
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
    }
    
    private func setupMockMachines() {
        for machine in machines {
            let annotation = MKPointAnnotation()
            annotation.coordinate = machine.coordinate
            annotation.title = "\(machine.name) ⭐️\(machine.rating)"
            annotation.subtitle = machine.schedule
            mapView.addAnnotation(annotation)
        }
        mapView.showAnnotations(mapView.annotations, animated: true)
    }
    
    // MARK: - MapView Delegate
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation,
              let machine = machines.first(where: { $0.coordinate.latitude == annotation.coordinate.latitude &&
                                                    $0.coordinate.longitude == annotation.coordinate.longitude }) else {
            return
        }
        showMachineSheet(machine: machine)
    }
    
    private func showMachineSheet(machine: CoffeeMachine) {
        let drinksList = machine.drinks.map { "\($0.name) \($0.price)₽" }.joined(separator: "\n")
        let message = "⭐️ \(machine.rating) (\(machine.reviewsCount) отзывов)\n\(drinksList)"
        
        let alert = UIAlertController(
            title: machine.name,
            message: message,
            preferredStyle: .actionSheet
        )
        
        let orderAction = UIAlertAction(title: "Принеси кофе", style: .default) { [weak self] _ in
            self?.startCourierSearch()
        }
        
        let cancel = UIAlertAction(title: "Закрыть", style: .cancel, handler: nil)
        
        alert.addAction(orderAction)
        alert.addAction(cancel)
        
        present(alert, animated: true, completion: nil)
    }
    
    private func startCourierSearch() {
        searchAlert = UIAlertController(
            title: "Поиск курьера",
            message: "Ищем исполнителя…",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Отменить поиск", style: .destructive) { [weak self] _ in
            self?.stopCourierSearch()
        }
        searchAlert?.addAction(cancelAction)
        
        if let searchAlert = searchAlert {
            present(searchAlert, animated: true, completion: nil)
        }
        
        let randomTime = Double.random(in: 3...5)
        searchTimer = Timer.scheduledTimer(
            withTimeInterval: randomTime,
            repeats: false
        ) { [weak self] _ in
            self?.stopCourierSearch(success: true)
        }
    }
    
    private func stopCourierSearch(success: Bool = false) {
        searchTimer?.invalidate()
        searchTimer = nil
        
        searchAlert?.dismiss(animated: true) { [weak self] in
            if success {
                let result = UIAlertController(
                    title: "Курьер найден ✅",
                    message: "Ваш заказ принят в работу!",
                    preferredStyle: .alert
                )
                result.addAction(UIAlertAction(title: "Ок", style: .default))
                self?.present(result, animated: true, completion: nil)
            }
        }
        
        searchAlert = nil
    }
}
