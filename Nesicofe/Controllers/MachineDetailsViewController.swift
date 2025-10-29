//
//  MachineDetailsViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

final class MachineDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    
    private let viewModel: MachineDetailsViewModel
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let toCartButton = UIButton(type: .system)
    
    init(viewModel: MachineDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { return nil }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //title = viewModel.title
        view.backgroundColor = .systemBackground
        setMachineName()
        setupTable()
        setupBottom()
        reloadData()
    }
    
    private func setMachineName() {
        title = viewModel.getMachineName()
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
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -80)
        ])
    }
    
    private func setupBottom() {
        toCartButton.translatesAutoresizingMaskIntoConstraints = false
        toCartButton.setTitle("Перейти в корзину", for: .normal)
        toCartButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        toCartButton.addTarget(self, action: #selector(openCartTab), for: .touchUpInside)
        view.addSubview(toCartButton)
        NSLayoutConstraint.activate([
            toCartButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toCartButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toCartButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            toCartButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func reloadData() {
        DispatchQueue.global().async {
            self.viewModel.onCartUpdated = { [weak self] in
                DispatchQueue.main.async {
                    self?.table.reloadData()
                }
            }
        }
    }
    
    @objc private func openCartTab() {
        viewModel.goToCart()
    }
    
    private func onShowError() {
        viewModel.onShowError = { [weak self] msg in
            let alert = UIAlertController(title: "Упс...", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    // UITableViewDataSource, UITableViewDelegate
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.numberOfItems
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ProductCell.reuse, for: indexPath) as? ProductCell else {
            return UITableViewCell()
        }
        let productCellViewModel = viewModel.productCellViewModel(for: indexPath)
        cell.configure(with: productCellViewModel)
        
        return cell
    }
}

