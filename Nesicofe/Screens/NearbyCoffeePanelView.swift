//
//  NearbyCoffeePanelView.swift
//  Nesicofe
//
//  Created by dev on 21/08/2025.
//

import UIKit
import CoreLocation

protocol NearbyCoffeePanelDelegate: AnyObject {
    func didSelectMachine(_ machine: CoffeeMachine)
}

final class NearbyCoffeePanelView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Кофе поблизости"
        label.font = .boldSystemFont(ofSize: 16)
        return label
    }()
    
    private var collectionView: UICollectionView?
    private var isExpanded = false
    private var panGesture: UIPanGestureRecognizer?
    private var bottomConstraint: NSLayoutConstraint?
    
    private var machines: [CoffeeMachine] = []
    private var userLocation: CLLocation?
    
    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Нет доступных кофемашин поблизости"
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    weak var delegate: NearbyCoffeePanelDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 16
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.2
        
        setupTitleLabel()
        setupCollectionView()
        setupPanGesture()
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupTitleLabel() {
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        ])
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 60)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(CoffeeCell.self, forCellWithReuseIdentifier: CoffeeCell.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(collectionView)   // <-- ВАЖНО: добавить ДО констрейнтов

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        self.collectionView = collectionView
        
        addSubview(emptyLabel)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
     private func setupPanGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(gesture)
        panGesture = gesture
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)
        switch gesture.state {
        case .changed:
            bottomConstraint?.constant = max(-superview.bounds.height / 2, (bottomConstraint?.constant ?? 0) + translation.y)
            gesture.setTranslation(.zero, in: superview)
        case .ended:
            if translation.y > 50 {
                collapseToTitleOnly()
            } else {
                expand()
            }
        default:
            break
        }
    }
    
    func updateMachines(_ machines: [CoffeeMachine], userLocation: CLLocation) {
        self.userLocation = userLocation
        self.machines = machines.filter {
            let loc = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            return loc.distance(from: userLocation) <= 1000
        }
        emptyLabel.isHidden = !self.machines.isEmpty
        collectionView?.reloadData()
    }
    
    func collapseToTitleOnly() {
        guard let superview = superview else { return }
        UIView.animate(withDuration: 0.3) {
            self.bottomConstraint?.constant = -100 // видно только заголовок
            superview.layoutIfNeeded()
            self.isExpanded = false
        }
    }
    
    func expand() {
        guard let superview = superview else { return }
        UIView.animate(withDuration: 0.3) {
            self.bottomConstraint?.constant = -superview.bounds.height / 2
            superview.layoutIfNeeded()
            self.isExpanded = true
        }
    }
    
    func hideForMachineDetail() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        }
    }

    func showAfterDetailClosed() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    // MARK: - UICollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return machines.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CoffeeCell.identifier, for: indexPath) as! CoffeeCell
        cell.configure(with: machines[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectMachine(machines[indexPath.item])
    }
}



