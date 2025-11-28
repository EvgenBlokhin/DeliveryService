//
//  OrdersViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit
import Combine

final class OrdersViewController: UITableViewController {
    private let vm: OrderViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: OrderViewModel) {
        self.vm = viewModel
        super.init(style: .plain)
        title = "Заказы"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        Task { await vm.loadOrders()
            tableView.reloadData() }
        //NotificationCenter.default.addObserver(self, selector: #selector(onCourierLocation(_:)), name: .courierLocationUpdated, object: nil)
    }

    @objc private func onCourierLocation(_ note: Notification) {
        Task { await vm.loadOrders()
            tableView.reloadData() }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.orders.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let o = vm.orders[indexPath.row]
        c.textLabel?.text = "Заказ \(String(describing: o.id)) — \(o.status.rawValue)"
        c.detailTextLabel?.text = "Машина \(o.machineId) )"
        return c
    }

//    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let o = vm.orders[indexPath.row]
//        let chatVM = ChatViewModel(orderId: o.id)
//        let chatVC = ChatViewController(viewModel: chatVM)
//        navigationController?.pushViewController(chatVC, animated: true)
//    }
}
