//
//  ProfileViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class ProfileViewController: UIViewController {
    let viewModel: ProfileViewModel
    private let name = UILabel()
    private let phone = UILabel()
    private let role = UILabel()
    private let rating = UILabel()
    private let logoutBtn = UIButton(type: .system)

    init(viewModel: ProfileViewModel) { self.viewModel = viewModel; super.init(nibName: nil, bundle: nil); title = "Профиль"; tabBarItem = .init(title: "Профиль", image: UIImage(systemName: "person.crop.circle"), tag: 3) }
    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [name, phone, role, rating, logoutBtn])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])

        logoutBtn.setTitle("Выйти", for: .normal)
        logoutBtn.addTarget(self, action: #selector(logout), for: .touchUpInside)

        update()
    }

    private func update() {
//        guard let u = viewModel.user else { return }
//        name.text = "Имя: \(u.name)"
//        phone.text = "Телефон: \(u.phone)"
//        role.text = "Роль: \(u.role == .customer ? "Покупатель" : "Курьер")"
//        rating.text = "Рейтинг: \(String(format: "%.1f", u.rating))"
    }

    @objc private func logout() async { await viewModel.logoutTapped() }
}
