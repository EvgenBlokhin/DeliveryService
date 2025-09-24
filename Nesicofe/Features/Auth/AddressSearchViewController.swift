//
//  AddressSearchDelegate.swift
//  Nesicofe
//
//  Created by dev on 22/08/2025.
//

import UIKit
import MapKit

//“protocol AddressSearchDelegate: AnyObject {
//    func didSelectAddress(_ coordinate: CLLocation)
//    func didTapEnableLocation()
//    func didSkipAddress()
//}”

final class AddressSearchViewController: UIViewController {
    
    private let locationService = LocationService.shared


    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("←", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        return button
    }()

    private let searchField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Введите адрес"
        textField.borderStyle = .roundedRect
        textField.clearButtonMode = .whileEditing
        return textField
    }()

    private let shareLabel: UILabel = {
        let label = UILabel()
        label.text = "Поделитесь геопозицией"
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    private let enableButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Включить", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        return button
    }()

    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true // скрыт пока нет поиска
        return table
    }()

    private var searchResults: [MKMapItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        setupActions()
        setupTableView()
    }

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(searchField)
        view.addSubview(shareLabel)
        view.addSubview(enableButton)
        view.addSubview(tableView)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        shareLabel.translatesAutoresizingMaskIntoConstraints = false
        enableButton.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Верхняя панель
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.widthAnchor.constraint(equalToConstant: 40),

            searchField.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            // Вторая строка
            shareLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            shareLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),

            enableButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            enableButton.centerYAnchor.constraint(equalTo: shareLabel.centerYAnchor),

            // Таблица
            tableView.topAnchor.constraint(equalTo: shareLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupActions() {
        backButton.addTarget(self, action: #selector(noAddressAndLocation), for: .touchUpInside)
        enableButton.addTarget(self, action: #selector(didTapEnableLocation), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    @objc func noAddressAndLocation(_ coordinate: CLLocation) {
        print("backButton")
    }
    
    @objc func didTapEnableLocation() {
        print("enableButton")
    }

    @objc private func textDidChange() {
        guard let query = searchField.text, !query.isEmpty else {
            searchResults.removeAll()
            tableView.isHidden = true
            tableView.reloadData()
            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        MKLocalSearch(request: request).start { [weak self] response, error in
            guard let self = self, let items = response?.mapItems else { return }
            self.searchResults = items
            self.tableView.isHidden = items.isEmpty
            self.tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDelegate/DataSource
extension AddressSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = searchResults[indexPath.row]
        cell.textLabel?.text = item.placemark.title
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let coordinate = searchResults[indexPath.row].placemark.coordinate
        //delegate?.didSelectAddress(coordinate)
    }
}
