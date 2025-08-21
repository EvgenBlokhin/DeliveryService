
// CoffeeMachineAnnotation.swift
import MapKit

final class CoffeeMachineAnnotation: NSObject, MKAnnotation {
    let machine: CoffeeMachine
    var coordinate: CLLocationCoordinate2D { machine.coordinate }
    var title: String? { machine.name }
    var subtitle: String? { machine.schedule } // график в подзаголовке

    init(machine: CoffeeMachine) { self.machine = machine; super.init() }
}

final class CoffeeMachineAnnotationView: MKMarkerAnnotationView {
    static let reuseId = "CoffeeMachineAnnotationView"

    override var annotation: MKAnnotation? {
        willSet {
            guard let ann = newValue as? CoffeeMachineAnnotation else { return }
            // Имя — в callout, график — subtitle, рейтинг — в глифе
            canShowCallout = true
            markerTintColor = .systemBrown
            glyphText = String(format: "%.1f", ann.machine.rating) // 4.8
            // Кнопка инфо (покажем нижний шит при тапе на сам пин — см. делегат)
            rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            displayPriority = .required
        }
    }
}
