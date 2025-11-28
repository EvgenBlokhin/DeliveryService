//
//  ChatViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit
import Combine

final class ChatViewController: UIViewController, UITableViewDataSource {
    private let vm: ChatViewModel
    private let table = UITableView()
    private let input = UITextField()
    private let sendBtn = UIButton(type: .system)
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ChatViewModel) {
        self.vm = viewModel
        super.init(nibName: nil, bundle: nil)
        title = "Чат"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        table.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 60)
        table.dataSource = self
        view.addSubview(table)

        input.frame = CGRect(x: 12, y: view.bounds.height - 52, width: view.bounds.width - 100, height: 40)
        input.borderStyle = .roundedRect
        view.addSubview(input)

        sendBtn.frame = CGRect(x: view.bounds.width - 80, y: view.bounds.height - 52, width: 68, height: 40)
        sendBtn.setTitle("Отправить", for: .normal)
        sendBtn.addTarget(self, action: #selector(onSend), for: .touchUpInside)
        view.addSubview(sendBtn)

        vm.$messages.sink { [weak self] _ in
            self?.table.reloadData()
            if let rows = self?.table.numberOfRows(inSection: 0), rows > 0 {
                self?.table.scrollToRow(at: IndexPath(row: rows - 1, section: 0), at: .bottom, animated: true)
            }
        }.store(in: &cancellables)
    }

    @objc private func onSend() {
        guard let txt = input.text, !txt.isEmpty else { return }
        vm.send(text: txt)
        input.text = ""
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let m = vm.messages[indexPath.row]
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        c.textLabel?.text = m.text
        c.detailTextLabel?.text = "\(m.fromUserId) • \(m.timestamp)"
        return c
    }
}
