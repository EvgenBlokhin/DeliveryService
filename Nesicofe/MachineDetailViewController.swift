import UIKit
import CoreLocation

final class MachineDetailViewController: UIViewController {
    
    private let machine: CoffeeMachine
    
    // MARK: - UI
    private let photosCollectionView: UICollectionView
    private let nameLabel = UILabel()
    private let ratingLabel = UILabel()
    private let scheduleLabel = UILabel()
    private let drinksStack = UIStackView()
    private let reviewsLabel = UILabel()
    private let orderButton = UIButton(type: .system)
    
    private var searchAlert: UIAlertController?
    private var searchTimer: Timer?
    
    // MARK: - Init
    init(machine: CoffeeMachine) {
        self.machine = machine
        
        // Layout for horizontal photos
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 120, height: 80)
        layout.minimumLineSpacing = 8
        self.photosCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(nibName: nil, bundle: nil)
        
        self.photosCollectionView.dataSource = self
        self.photosCollectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        setupUI()
        configureWithMachine()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Photos
        photosCollectionView.backgroundColor = .clear
        photosCollectionView.showsHorizontalScrollIndicator = false
        
        // Labels
        nameLabel.font = .boldSystemFont(ofSize: 20)
        ratingLabel.font = .systemFont(ofSize: 16)
        scheduleLabel.font = .systemFont(ofSize: 14)
        scheduleLabel.textColor = .secondaryLabel
        reviewsLabel.font = .systemFont(ofSize: 14)
        reviewsLabel.textColor = .secondaryLabel
        
        // Drinks stack
        drinksStack.axis = .vertical
        drinksStack.spacing = 4
        
        // Order button
        orderButton.setTitle("Принеси кофе", for: .normal)
        orderButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        orderButton.backgroundColor = .systemBrown
        orderButton.setTitleColor(.white, for: .normal)
        orderButton.layer.cornerRadius = 8
        orderButton.addTarget(self, action: #selector(orderTapped), for: .touchUpInside)
        
        // Layout
        let stack = UIStackView(arrangedSubviews: [
            photosCollectionView,
            nameLabel,
            ratingLabel,
            scheduleLabel,
            drinksStack,
            reviewsLabel,
            orderButton
        ])
        stack.axis = .vertical
        stack.spacing = 12
        
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
            photosCollectionView.heightAnchor.constraint(equalToConstant: 100),
            orderButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func configureWithMachine() {
        nameLabel.text = machine.name
        ratingLabel.text = "⭐️ \(machine.rating)"
        scheduleLabel.text = "График: \(machine.schedule)"
        reviewsLabel.text = "Отзывы: \(machine.reviewsCount)"
        
        drinksStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for drink in machine.drinks {
            let label = UILabel()
            label.text = "\(drink.name) — \(drink.price)₽"
            drinksStack.addArrangedSubview(label)
        }
    }
    
    // MARK: - Actions
    @objc private func orderTapped() {
        let alert = UIAlertController(title: "Ищем исполнителя…",
                                      message: nil,
                                      preferredStyle: .alert)
        
        // Индикатор
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        
        alert.view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20)
        ])
        
        // Кнопка отмены
        alert.addAction(UIAlertAction(title: "Отменить поиск", style: .cancel) { [weak self] _ in
            self?.stopSearch(cancelled: true)
        })
        
        present(alert, animated: true)
        searchAlert = alert
        
        // Таймер-симулятор
        searchTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.stopSearch(cancelled: false)
        }
    }
    
    private func stopSearch(cancelled: Bool) {
        searchTimer?.invalidate()
        searchTimer = nil
        searchAlert?.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            let result = UIAlertController(
                title: cancelled ? "Поиск отменён" : "Курьер найден ✅",
                message: nil,
                preferredStyle: .alert
            )
            result.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(result, animated: true)
        }
    }
}

// MARK: - CollectionView for Photos
extension MachineDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        machine.photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let imageName = machine.photos[indexPath.item]
        cell.imageView.image = UIImage(named: imageName)
        return cell
    }
}
