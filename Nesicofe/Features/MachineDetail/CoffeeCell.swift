//
//  CoffeeCell.swift
//  Nesicofe
//
//  Created by dev on 23/08/2025.
//

import UIKit

final class CoffeeCell: UICollectionViewCell {
    static let identifier = "CoffeeCell"
    
    private let nameLabel = UILabel()
    private let ratingLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 8
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(ratingLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        ratingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            ratingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            ratingLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(with machine: CoffeeMachine) {
        nameLabel.text = machine.name
        ratingLabel.text = "⭐️ \(machine.rating)"
    }
}
