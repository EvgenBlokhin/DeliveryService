//
//  ProductCell.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class ProductCell: UITableViewCell {
    static let reuse = "ProductCell"
    
    private var viewModel: ProductCellViewModel?

    private let coffeeImageView = UIImageView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let sugarLabel = UILabel()
    private let sugarStepper = UIStepper()
    private let countView = CounterView()

    var onSugarChanged: ((Int) -> Void)?
    var onCountChanged: ((Int) -> Void)?
    var onProductRemove: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        coffeeImageView.contentMode = .scaleAspectFill
        coffeeImageView.layer.cornerRadius = 8
        coffeeImageView.clipsToBounds = true
        coffeeImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coffeeImageView.widthAnchor.constraint(equalToConstant: 60),
            coffeeImageView.heightAnchor.constraint(equalToConstant: 60)
        ])

        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        priceLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        sugarLabel.font = .systemFont(ofSize: 13)
        sugarLabel.textColor = .secondaryLabel

        sugarStepper.minimumValue = 0
        sugarStepper.maximumValue = 5
        sugarStepper.addTarget(self, action: #selector(sugarChanged), for: .valueChanged)

        countView.onValueChanged = { [weak self] newValue in
            guard let viewModel = self?.viewModel else { return }
            self?.viewModel = viewModel
            self?.onCountChanged?(newValue)
        }
        countView.onProductRemove = { [weak self] in
            guard let viewModel = self?.viewModel else { return }
            self?.viewModel = viewModel
            self?.onProductRemove?()
        }

        let textStack = UIStackView(arrangedSubviews: [nameLabel, priceLabel, sugarLabel, sugarStepper])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let hStack = UIStackView(arrangedSubviews: [coffeeImageView, textStack, countView])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            hStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            hStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            hStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    
    func configure(with viewModel: ProductCellViewModel) {
        // Сохранить VM (struct) — ячейка будет мутировать локальную копию,
            // а VM.on... уже направит изменения в контроллер/сервис
        self.viewModel = viewModel
        nameLabel.text = viewModel.name
        priceLabel.text = viewModel.priceText
        sugarLabel.text = "Сахар: \(viewModel.sugarLevel)"
        sugarStepper.value = Double(viewModel.sugarLevel)
        countView.value = viewModel.countDrink
        coffeeImageView.image = viewModel.image
//
        // проброс колбеков
        self.onSugarChanged = viewModel.onSugarChanged
        self.onCountChanged = viewModel.onCountChanged
        self.onProductRemove = viewModel.onProductRemove
    }

    @objc private func sugarChanged() {
        guard let viewModel = viewModel else { return }
        let newValue = Int(sugarStepper.value)
        self.onSugarChanged?(newValue)
        sugarLabel.text = "Сахар: \(viewModel.sugarLevel)"
        self.viewModel = viewModel
    }
}
