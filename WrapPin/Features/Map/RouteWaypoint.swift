import CoreLocation
import MapKit
import Foundation

struct RouteWaypoint: Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let name: String?
    let address: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.address == rhs.address
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, name: String? = nil, address: String? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.name = name
        self.address = address
    }

    init(id: UUID = UUID(), target: LocationTarget) {
        self.init(id: id, coordinate: target.coordinate, name: target.name, address: target.subtitle)
    }
}

enum RoutePointRole {
    case start, destination, waypoint, replace(UUID)

    var title: String {
        switch self {
        case .start: String(localized: "Choose route start")
        case .destination: String(localized: "Choose destination")
        case .waypoint: String(localized: "Add waypoint")
        case .replace: String(localized: "Replace route point")
        }
    }

    /// Adding a waypoint preserves the destination; replacing preserves row identity.
    @discardableResult
    func apply(_ target: LocationTarget, to points: inout [RouteWaypoint], limit: Int) -> Bool {
        guard CLLocationCoordinate2DIsValid(target.coordinate) else { return false }
        let index: Int
        switch self {
        case .replace(let id):
            guard let existing = points.firstIndex(where: { $0.id == id }) else { return false }
            points[existing] = RouteWaypoint(id: id, target: target)
            return true
        case .start where !points.isEmpty:
            points[0] = RouteWaypoint(id: points[0].id, target: target)
            return true
        case .destination where points.count >= 2:
            points[points.count - 1] = RouteWaypoint(id: points.last!.id, target: target)
            return true
        case .waypoint:
            index = points.count >= 2 ? points.count - 1 : points.count
        case .start, .destination:
            index = points.count
        }
        guard points.count < limit else { return false }
        points.insert(RouteWaypoint(target: target), at: index)
        return true
    }
}

struct RoutePlacePickerRequest: Identifiable {
    let id = UUID()
    let role: RoutePointRole
    let region: MKCoordinateRegion?
}
