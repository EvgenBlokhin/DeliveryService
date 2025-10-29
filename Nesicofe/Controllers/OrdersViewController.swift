//
//  OrdersViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit

class OrdersViewController: UITableViewController {
    private let viewModel: OrdersViewModel

    init(viewModel: OrdersViewModel) {
        self.viewModel = viewModel
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Мои заказы"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        Task {
            await viewModel.loadOrders()
            tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.orders.count
    }
    override func tableView(_ table: UITableView, cellForRowAt idx: IndexPath) -> UITableViewCell {
        let c = table.dequeueReusableCell(withIdentifier: "cell", for: idx)
        let order = viewModel.orders[idx.row]
        c.textLabel?.text = "Order \(order.id) — \(order.status)"
        return c
    }
}
