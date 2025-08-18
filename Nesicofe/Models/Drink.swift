
// Models.swift
import CoreLocation

struct Drink: Identifiable {
    let id: String
    let name: String
    let price: Double
}


extension Array where Element == Drink {
    var priceRangeText: String {
        guard let min = self.map({ $0.price }).min(),
              let max = self.map({ $0.price }).max() else { return "—" }
        return min == max ? String(format: "₽%.0f", min) : String(format: "₽%.0f–%.0f", min, max)
    }
}

