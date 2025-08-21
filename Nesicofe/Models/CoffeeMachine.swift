import CoreLocation

struct CoffeeMachine: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let rating: Double
    let schedule: String      // график работы — краткая строка
    let photos: [String]      // имена картинок в Assets
    let drinks: [Drink]
    let reviewsCount: Int
}
