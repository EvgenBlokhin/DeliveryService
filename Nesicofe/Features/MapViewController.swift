
import UIKit
import MapKit


class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, NearbyCoffeePanelDelegate, LocationServiceDelegate {
    
    private let mapView = MKMapView()
    private let coordinator: AppCoordinator?
    private let locationService = LocationService.shared
    private let nearbyPanel = NearbyCoffeePanelView()
    private var coffeeMachines: [CoffeeMachine] = []
    private var nearbyPanelBottomConstraint: NSLayoutConstraint?

    var shouldShowNearbyPanel: Bool = true
    
    init(coordinator: AppCoordinator?) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Карта кофемашин"
        view.backgroundColor = .systemBackground
        
        mapView.delegate = self
        locationService.delegate = self
        nearbyPanel.delegate = self
        
        setupMap()
        setupNearbyPanel()
        addCoffeeMachines()
        setupProfileButton()
        //setupNearbyPanel()
        
        
        
    }
    // MARK: - Setup Map
    private func setupMap() {
        mapView.frame = view.bounds
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        view.addSubview(mapView)
    }
    
    // MARK: - setupLocationService
    private func setupNearbyPanel() {
        if locationService.handleAuthorizationStatus() {
            updateCoffeePanel()
            additionsNearbyPanel()
            print("setupNearbyPanel")
        }
    }
    
    // MARK: - Добавляем кофемашины на карту
    private func addCoffeeMachines() {
        let machines = MockDataProvider.getCoffeeMachines()
        coffeeMachines = machines
        for machine in machines {
            let annotation = MKPointAnnotation()
            annotation.title = machine.name
            annotation.subtitle = "⭐️ \(machine.rating) | \(machine.schedule)"
            annotation.coordinate = machine.coordinate
            
            mapView.addAnnotation(annotation)
        }
    }
    
    // MARK: - setupNearbyCoffeePanel
    private func additionsNearbyPanel() {
        nearbyPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nearbyPanel)
        nearbyPanelBottomConstraint = nearbyPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        NSLayoutConstraint.activate([
            nearbyPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            nearbyPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nearbyPanel.heightAnchor.constraint(equalToConstant: 300),
            nearbyPanelBottomConstraint!
        ])
        nearbyPanel.layoutIfNeeded()
    }
  //  MARK: - UpdateNearbyCoffeePanel
    private func updateCoffeePanel() {
        locationService.startUpdatingLocation { [weak self] location in
            guard let self = self else { return }
            self.centerMap(on: location)
            self.nearbyPanel.updateMachines(MockDataProvider.getCoffeeMachines(), userLocation: location)
        }
    }
    // MARK: - Nearby Panel Controls
    func expandPanel() {
        nearbyPanelBottomConstraint?.constant = -20
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    func collapsePanel() {
        nearbyPanelBottomConstraint?.constant = -100
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - StartLocation
    func centerMap(on location: CLLocation, radius: CLLocationDistance = 500) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )
        mapView.setRegion(region, animated: true)
    }
    
    //MARK: - Setup Profile
    private func setupProfileButton() {
        let profileButton = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain,
            target: self,
            action: #selector(openProfile)
        )
        navigationItem.leftBarButtonItem = profileButton
    }
    
    @objc private func openProfile() {
        let profileVC = UIViewController()
        profileVC.view.backgroundColor = .systemBackground
        profileVC.title = "Профиль"
        navigationController?.pushViewController(profileVC, animated: true)
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController {
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation,
              let annotationTitle = annotation.title ?? nil,
              let machine = coffeeMachines.first(where: { $0.name == annotationTitle }) else { return }
        
        let detailVC = MachineDetailViewController(machine: machine)
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(detailVC, animated: true, completion: nil)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }

        let identifier = "CoffeeMachineAnnotation"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

        annotationView.annotation = annotation
        annotationView.canShowCallout = true
        annotationView.glyphText = "☕️"
        annotationView.markerTintColor = .brown
        annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)

        return annotationView
    }

}

// MARK: - LocationServiceDelegate

extension MapViewController {
    func locationService(_ service: LocationService, didUpdateLocation location: CLLocation) {
        
        centerMap(on: location)
        print("centerMap")
        locationService.stopUpdatingLocation()
    }

    func locationServiceDidChangeAuthorization(_ service: LocationService, status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            print("locationServiceDidChangeAuthorization")
            }
        }
    }
// MARK: - NearbyCoffeePanelDelegate
extension MapViewController {
    func didSelectMachine(_ machine: CoffeeMachine) {
        let detailVC = MachineDetailViewController(machine: machine)
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
        }
        present(detailVC, animated: true, completion: nil)
    }
}


