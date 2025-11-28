//
//  CounterView.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class CounterView: UIView {
    private let minus = UIButton(type: .system)
    private let plus = UIButton(type: .system)
    private let label = UILabel()

    var value: Int = 1 {
        didSet { label.text = "\(value)" }
    }

    var onValueChanged: ((Int) -> Void)?
    var onProductRemove: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        minus.setTitle("−", for: .normal)
        minus.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        plus.setTitle("+", for: .normal)
        plus.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)

        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.text = "\(value)"

        let stack = UIStackView(arrangedSubviews: [minus, label, plus])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            minus.widthAnchor.constraint(equalToConstant: 30),
            plus.widthAnchor.constraint(equalToConstant: 30)
        ])

        minus.addTarget(self, action: #selector(dec), for: .touchUpInside)
        plus.addTarget(self, action: #selector(inc), for: .touchUpInside)
    }

    @objc private func dec() {
        if value > 1 {
            value -= 1
            onValueChanged?(value)
        } else if value == 1 {
            // при уменьшении с 1 до 0 считаем это удалением продукта
            value = 0
            onProductRemove?()
        }
    }

    @objc private func inc() {
        value += 1
        onValueChanged?(value)
    }
}
