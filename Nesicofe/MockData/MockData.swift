
// MockData.swift
import CoreLocation

final class MockDataProvider {
    static func getCoffeeMachines() -> [CoffeeMachine] {
        return [
            CoffeeMachine(
                id: "m1",
                name: "Seven Coffee — Дюна",
                coordinate: CLLocationCoordinate2D(latitude: 54.253638, longitude: 48.315352),
                rating: 4.8,
                schedule: "Пн–Вс 09:00– 18:00",
                photos: ["coffee1", "coffee2", "coffee3"],
                drinks: [
                    Drink(id: "d1", name: "2й экспрессо", price: 120),
                    Drink(id: "d1", name: "Американо Большой", price: 230),
                    Drink(id: "d2", name: "Американо Гранд", price: 320),
                    Drink(id: "d3", name: "Капучинро Большой",    price: 270),
                    Drink(id: "d1", name: "Латте", price: 330),
                    Drink(id: "d1", name: "Флет Уайт", price: 240),
                    Drink(id: "d1", name: "Кофе с молоком", price: 300),
                    Drink(id: "d1", name: "Чай", price: 200),
                ],
                reviewsCount: 126
            ),
            CoffeeMachine(
                id: "m2",
                name: "Coffee Van — Парк",
                coordinate: CLLocationCoordinate2D(latitude: 54.254909, longitude: 48.319603),
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
}
