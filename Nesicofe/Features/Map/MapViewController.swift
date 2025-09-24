
import UIKit
import MapKit
import Combine

final class MapViewController: UIViewController {
    
    private let viewModel: MapViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let map = MKMapView()
    private let addressLabel = UILabel()
    private let addressContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let geoButton = UIButton(type: .system)
    private let chatButton = UIButton(type: .system)
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "Карта"
        tabBarItem = UITabBarItem(title: "Карта", image: UIImage(systemName: "map"), tag: 0)
    }
    required init?(coder: NSCoder) { return nil }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        
        setupMap()
        setupAddressBar()
        setupGeoButton()
        setupChatButton()
        
        bindViewModel()
        viewModel.loadMachines()
    }
    
    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.addressLabel.text = state.address
                self.centerMap(to: state.center)
                self.updateAnnotations(state.annotations)
                self.chatButton.isHidden = true
            }
            .store(in: &cancellables)
    }
    
    private func setupMap() {
        map.translatesAutoresizingMaskIntoConstraints = false
        map.delegate = self
        view.addSubview(map)
        
        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        map.mapType = .standard
        map.showsUserLocation = true
        map.isRotateEnabled = true
        map.pointOfInterestFilter = .includingAll
    }
    
    private func setupAddressBar() {
        addressContainer.translatesAutoresizingMaskIntoConstraints = false
        addressContainer.layer.cornerRadius = 12
        addressContainer.clipsToBounds = true
        
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addressLabel.font = .systemFont(ofSize: 15, weight: .medium)
        addressLabel.textColor = .label
        addressLabel.numberOfLines = 2
        addressLabel.textAlignment = .center
        addressContainer.contentView.addSubview(addressLabel)
        
        view.addSubview(addressContainer)
        NSLayoutConstraint.activate([
            addressContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            addressContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addressContainer.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),
            
            addressLabel.leadingAnchor.constraint(equalTo: addressContainer.leadingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: addressContainer.trailingAnchor, constant: -12),
            addressLabel.topAnchor.constraint(equalTo: addressContainer.topAnchor, constant: 10),
            addressLabel.bottomAnchor.constraint(equalTo: addressContainer.bottomAnchor, constant: -10)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(editAddress))
        addressContainer.addGestureRecognizer(tap)
    }
    
    private func setupGeoButton() {
        geoButton.translatesAutoresizingMaskIntoConstraints = false
        geoButton.setImage(UIImage(systemName: "location"), for: .normal)
        geoButton.tintColor = .white
        geoButton.backgroundColor = .systemBlue
        geoButton.layer.cornerRadius = 26
        geoButton.addTarget(self, action: #selector(centerOnCurrent), for: .touchUpInside)
        
        view.addSubview(geoButton)
        NSLayoutConstraint.activate([
            geoButton.widthAnchor.constraint(equalToConstant: 52),
            geoButton.heightAnchor.constraint(equalToConstant: 52),
            geoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            geoButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupChatButton() {
        chatButton.translatesAutoresizingMaskIntoConstraints = false
        chatButton.setImage(UIImage(systemName: "bubble.left.and.bubble.right"), for: .normal)
        chatButton.tintColor = .white
        chatButton.backgroundColor = .systemGreen
        chatButton.layer.cornerRadius = 26
        chatButton.addTarget(self, action: #selector(openLastChat), for: .touchUpInside)
        
        view.addSubview(chatButton)
        NSLayoutConstraint.activate([
            chatButton.widthAnchor.constraint(equalToConstant: 52),
            chatButton.heightAnchor.constraint(equalToConstant: 52),
            chatButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            chatButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    private func centerMap(to coord: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: coord, latitudinalMeters: 5000, longitudinalMeters: 5000)
        map.setRegion(region, animated: true)
    }
    
    private func updateAnnotations(_ list: [MapAnnotation]) {
        let nonUserAnnotations = map.annotations.filter { !($0 is MKUserLocation) }
        map.removeAnnotations(nonUserAnnotations)

        for ann in list {
            let annotation = CustomPointAnnotation()
            annotation.coordinate = ann.coordinate
            annotation.title = ann.title
            annotation.id = ann.id
            annotation.isCourier = ann.isCourier
            map.addAnnotation(annotation)
        }
    }
    
    @objc private func centerOnCurrent() {
        viewModel.centerOnCurrent()
    }
    
    @objc private func editAddress() {
        showTextPrompt(title: "Изменить адрес",
                       message: "Введите адрес вручную",
                       placeholder: "Ульяновск, улица, дом",
                       initial: nil) { [weak self] text in
            self?.viewModel.setManualAddress(text) { result in
                if case .failure(let e) = result {
                    self?.alert("Адрес", e.localizedDescription)
                }
            }
        }
    }
    
    @objc private func openLastChat() {
        // делегируем во ViewModel → дальше решает координатор
        viewModel.onOpenChat?("lastOrder")
    }
}
