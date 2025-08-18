
// MockData.swift
import CoreLocation

enum MockData {
    static let machines: [CoffeeMachine] = [
        CoffeeMachine(
            id: "m1",
            name: "Coffee Car — Центр",
            coordinate: CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6176),
            rating: 4.8,
            schedule: "Пн–Вс 08:00–22:00",
            photos: ["coffee1", "coffee2", "coffee3"],
            drinks: [
                Drink(id: "d1", name: "Эспрессо", price: 120),
                Drink(id: "d2", name: "Капучино", price: 180),
                Drink(id: "d3", name: "Латте",    price: 190)
            ],
            reviewsCount: 126
        ),
        CoffeeMachine(
            id: "m2",
            name: "Coffee Van — Парк",
            coordinate: CLLocationCoordinate2D(latitude: 55.7600, longitude: 37.6200),
            rating: 4.6,
            schedule: "Пн–Пт 09:00–20:00",
            photos: ["coffee2", "coffee3", "coffee1"],
            drinks: [
                Drink(id: "d4", name: "Американо", price: 130),
                Drink(id: "d5", name: "Флэт уайт", price: 210)
            ],
            reviewsCount: 74
        )
    ]
}
