//
//  ChatViewController.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//
import UIKit
import Combine

class ChatViewController: UIViewController, UITableViewDataSource {
    private let viewModel: ChatViewModel
    private let table = UITableView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        table.dataSource = self
        view.addSubview(table)
        view.addSubview(inputField)
        view.addSubview(sendButton)

        // layout — простой, без Autolayout, для примера
        table.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 50)
        inputField.frame = CGRect(x: 10, y: view.bounds.height - 44, width: view.bounds.width - 80, height: 44)
        sendButton.frame = CGRect(x: view.bounds.width - 60, y: view.bounds.height - 44, width: 50, height: 44)
        sendButton.setTitle("Send", for: .normal)
        sendButton.addTarget(self, action: #selector(onSend), for: .touchUpInside)

        viewModel.$messages.sink { [weak self] _ in
            self?.table.reloadData()
            if let c = self {
                let rows = c.table.numberOfRows(inSection: 0)
                if rows > 0 {
                    c.table.scrollToRow(at: IndexPath(row: rows-1, section: 0), at: .bottom, animated: true)
                }
            }
        }.store(in: &cancellables)
    }

    @objc private func onSend() {
        guard let txt = inputField.text, !txt.isEmpty,
              let userId = viewModel.chatService.socket.tokenStore.getToken(forKey: "userId") else {
            return
        }
        viewModel.send(text: txt, fromUserId: userId)
        inputField.text = ""
    }

    func tableView(_ t: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.messages.count
    }
    func tableView(_ t: UITableView, cellForRowAt idx: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let msg = viewModel.messages[idx.row]
        c.textLabel?.text = msg.text
        c.detailTextLabel?.text = "\(msg.fromUserId) — \(msg.timestamp)"
        return c
    }
}
