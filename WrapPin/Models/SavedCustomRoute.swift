import CoreLocation
import Foundation

struct SavedCustomRoutePoint: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let name: String?
    let address: String?

    init(latitude: Double, longitude: Double, name: String? = nil, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.address = address
    }

    init(waypoint: RouteWaypoint) {
        self.latitude = waypoint.coordinate.latitude
        self.longitude = waypoint.coordinate.longitude
        self.name = waypoint.name
        self.address = waypoint.address
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var waypoint: RouteWaypoint {
        RouteWaypoint(coordinate: coordinate, name: name, address: address)
    }
}

struct SavedCustomRoute: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let points: [SavedCustomRoutePoint]
    let coordinateMode: FixedCoordinateMode
    let speedKilometresPerHour: Double
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        points: [SavedCustomRoutePoint],
        coordinateMode: FixedCoordinateMode,
        speedKilometresPerHour: Double,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.points = points
        self.coordinateMode = coordinateMode
        self.speedKilometresPerHour = speedKilometresPerHour.isFinite
            ? min(max(speedKilometresPerHour, 0.1), 240)
            : 5
        self.updatedAt = updatedAt
    }

    var coordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }

    var waypoints: [RouteWaypoint] {
        points.map(\.waypoint)
    }

    /// Deterministic geometry + coordinate mode key so favouriting and history
    /// deduplication match the same route across restarts and renames.
    var contentFingerprint: String {
        let pointKeys = points.map {
            String(
                format: "%.6f,%.6f",
                locale: Locale(identifier: "en_US_POSIX"),
                $0.latitude,
                $0.longitude
            )
        }
        return "\(coordinateMode.rawValue)|\(pointKeys.joined(separator: ";"))"
    }

    func renamed(to proposedName: String) -> Self {
        Self(
            id: id,
            name: proposedName,
            points: points,
            coordinateMode: coordinateMode,
            speedKilometresPerHour: speedKilometresPerHour,
            updatedAt: updatedAt
        )
    }

    func withUpdatedMetadata(speedKilometresPerHour: Double, updatedAt: Date = .now) -> Self {
        Self(
            id: id,
            name: name,
            points: points,
            coordinateMode: coordinateMode,
            speedKilometresPerHour: speedKilometresPerHour,
            updatedAt: updatedAt
        )
    }

    static func defaultName(from waypoints: [RouteWaypoint]) -> String {
        let start = waypoints.first?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = waypoints.last?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericNames: Set<String> = ["Map point", "地图选点", "Dropped Pin", "Entered Location", "坐标位置"]

        let usableStart = start.flatMap { !$0.isEmpty && !genericNames.contains($0) ? $0 : nil }
        let usableEnd = end.flatMap { !$0.isEmpty && !genericNames.contains($0) ? $0 : nil }

        if let usableStart, let usableEnd, usableStart != usableEnd {
            return "\(usableStart) → \(usableEnd)"
        }
        if let usableEnd {
            return usableEnd
        }
        if let usableStart {
            return usableStart
        }
        return String(localized: "Custom route")
    }
}
