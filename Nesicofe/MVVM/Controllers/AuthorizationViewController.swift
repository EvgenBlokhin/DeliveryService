//
//  AuthorizationViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class AuthorizationViewController: UIViewController {
    let viewModel: AuthorizationViewModel

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let nameField = UITextField()
    private let phoneField = UITextField()
    private let roleSeg = UISegmentedControl(items: ["Покупатель", "Курьер"])
    private let loginBtn = UIButton(type: .system)
    private let registerBtn = UIButton(type: .system)

    init(viewModel: AuthorizationViewModel) { self.viewModel = viewModel; super.init(nibName: nil, bundle: nil); title = "Авторизация"; tabBarItem = .init(title: "Профиль", image: UIImage(systemName: "person.crop.circle"), tag: 3) }
    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        bind()
    }

    private func setupUI() {
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        nameField.placeholder = "Имя"
        nameField.borderStyle = .roundedRect
        nameField.returnKeyType = .done

        phoneField.placeholder = "Телефон"
        phoneField.borderStyle = .roundedRect
        phoneField.keyboardType = .phonePad

        roleSeg.selectedSegmentIndex = 0

        loginBtn.setTitle("Войти", for: .normal)
        registerBtn.setTitle("Зарегистрироваться", for: .normal)

        [nameField, phoneField, roleSeg, loginBtn, registerBtn].forEach { stack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: scroll.bottomAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        view.addGestureRecognizer(tap)
    }

    private func bind() {
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        phoneField.addTarget(self, action: #selector(phoneChanged), for: .editingChanged)
        roleSeg.addTarget(self, action: #selector(roleChanged), for: .valueChanged)
        loginBtn.addTarget(self, action: #selector(login), for: .touchUpInside)
        registerBtn.addTarget(self, action: #selector(registerUser), for: .touchUpInside)

        viewModel.onError = { [weak self] msg in
            self?.alert("Упс...", msg)
        }
    }

    @objc private func hideKeyboard() { view.endEditing(true) }
    @objc private func nameChanged() { viewModel.name = nameField.text ?? "" }
    @objc private func phoneChanged() { viewModel.phone = phoneField.text ?? "" }
    @objc private func roleChanged() { viewModel.role = (roleSeg.selectedSegmentIndex == 0) ? .customer : .courier }

    @objc private func login() async { await viewModel.loginTapped() }
    @objc private func registerUser() async { await viewModel.registerTapped() }
}
