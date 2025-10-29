//
//  CartViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class CartViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let viewModel: CartViewModel
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let totalLabel = UILabel()
    private let orderButton = UIButton(type: .system)
    
    

    init(viewModel: CartViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "Корзина"
        tabBarItem = .init(title: "Корзина", image: UIImage(systemName: "cart"), tag: 2)
    }
    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTable()
        setupBottom()
        bindVM()
        reload()
    }
    

    private func bindVM() {
        
        viewModel.onNeedAddress = { [weak self] in self?.askAddress() }
        viewModel.onError = { [weak self] msg in self?.presentAlert(title: "Упс...", message: msg) }
        viewModel.onOrderCreated = { [weak self] order in
            self?.presentAlert(title: "Заказ создан", message: "№\(order.id)")
        }
    }

    private func setupTable() {
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.register(ProductCell.self, forCellReuseIdentifier: ProductCell.reuse)
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
    }

    private func setupBottom() {
        totalLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        totalLabel.textAlignment = .center

        orderButton.setTitle("Принести кофе", for: .normal)
        orderButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        orderButton.backgroundColor = .systemBlue
        orderButton.tintColor = .white
        orderButton.layer.cornerRadius = 12
        orderButton.addTarget(self, action: #selector(orderTapped), for: .touchUpInside)

        let v = UIStackView(arrangedSubviews: [totalLabel, orderButton])
        v.axis = .vertical
        v.spacing = 8
        v.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            v.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            orderButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    func reload() {
        self.viewModel.onUpdated = { [weak self] in
                DispatchQueue.main.async {
                    self?.totalLabel.text = "Итого: \(Int(self?.viewModel.total ?? 0))₽"
                    self?.orderButton.isEnabled = self?.viewModel.activeMachineId != nil
                    self?.table.reloadData()
            }
        }
    }

    @objc private func orderTapped() async {
        await viewModel.placeOrder()
    }

    func askAddress() {
        showTextPrompt(
            title: "Адрес доставки",
            message: "Уточните адрес вручную или включите геопозицию на экране карты",
            placeholder: AppConstants.defaultAddress,
            initial: nil
        ) { _ in }
    }

    func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "Ок", style: .default))
        present(alert, animated: true)
    }

    // MARK:  TableView DataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sec = viewModel.sections[section]
        let prefix = sec.isActive ? "✅ " : ""
        return prefix + sec.address
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ProductCell.reuse,
            for: indexPath
        ) as? ProductCell else {
            return UITableViewCell()
        }
        let cellViewModel = viewModel.productCellViewModel(for: indexPath)
            cell.configure(with: cellViewModel)
            return cell
    }


    // MARK:  TableView Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sec = viewModel.sections[section]

        let btn = UIButton(type: .system)
        btn.setTitle(sec.isActive ? "✅ \(sec.address)" : sec.address, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: sec.isActive ? .bold : .regular)
        btn.contentHorizontalAlignment = .left
        btn.tag = section
        btn.addTarget(self, action: #selector(headerTapped(_:)), for: .touchUpInside)

        let container = UIView()
        container.addSubview(btn)
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            btn.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }

    @objc private func headerTapped(_ sender: UIButton) {
        let sec = viewModel.sections[sender.tag]
        viewModel.setActiveSection(sec.machineId)
    }
}
