import CoreLocation
import Foundation

@main
struct TestSavedCustomRoutes {
    static func main() throws {
        let start = RouteWaypoint(
            coordinate: CLLocationCoordinate2D(latitude: 31.230416, longitude: 121.473701),
            name: "People's Square",
            address: "Shanghai"
        )
        let mid = RouteWaypoint(
            coordinate: CLLocationCoordinate2D(latitude: 31.235200, longitude: 121.481000),
            name: "Map point",
            address: nil
        )
        let end = RouteWaypoint(
            coordinate: CLLocationCoordinate2D(latitude: 31.240000, longitude: 121.490500),
            name: "The Bund",
            address: "Shanghai"
        )

        let defaultName = SavedCustomRoute.defaultName(from: [start, mid, end])
        precondition(defaultName == "People's Square → The Bund", "Expected start → end default name, got \(defaultName)")

        let genericOnlyName = SavedCustomRoute.defaultName(from: [
            RouteWaypoint(coordinate: start.coordinate, name: "Map point"),
            RouteWaypoint(coordinate: end.coordinate, name: "地图选点")
        ])
        precondition(genericOnlyName == String(localized: "Custom route"), "Generic point names should fall back to Custom route")

        let route = SavedCustomRoute(
            name: defaultName,
            points: [start, mid, end].map(SavedCustomRoutePoint.init),
            coordinateMode: .gcj02,
            speedKilometresPerHour: 12.5
        )

        // JSON round-trip preserves all points, names, coordinate mode and speed.
        let encoded = try JSONEncoder().encode([route])
        let decoded = try JSONDecoder().decode([SavedCustomRoute].self, from: encoded)
        precondition(decoded.count == 1)
        precondition(decoded[0].points.count == 3)
        precondition(decoded[0].coordinateMode == .gcj02)
        precondition(decoded[0].speedKilometresPerHour == 12.5)
        precondition(decoded[0].waypoints.first?.name == "People's Square")
        precondition(decoded[0].waypoints.last?.name == "The Bund")

        // Content fingerprint stays stable across renames and fresh instances with the same geometry.
        let renamed = route.renamed(to: "Morning Jog")
        precondition(renamed.name == "Morning Jog")
        precondition(renamed.contentFingerprint == route.contentFingerprint)

        let wgsVariant = SavedCustomRoute(
            name: defaultName,
            points: [start, mid, end].map(SavedCustomRoutePoint.init),
            coordinateMode: .wgs84,
            speedKilometresPerHour: 12.5
        )
        precondition(wgsVariant.contentFingerprint != route.contentFingerprint, "Different coordinate modes must have distinct fingerprints")

        // Out-of-range speed values are clamped safely.
        let clampedLow = SavedCustomRoute(
            name: "Slow",
            points: [start, end].map(SavedCustomRoutePoint.init),
            coordinateMode: .wgs84,
            speedKilometresPerHour: -10
        )
        precondition(clampedLow.speedKilometresPerHour == 0.1)
        let clampedHigh = SavedCustomRoute(
            name: "Fast",
            points: [start, end].map(SavedCustomRoutePoint.init),
            coordinateMode: .wgs84,
            speedKilometresPerHour: 999
        )
        precondition(clampedHigh.speedKilometresPerHour == 240)

        print("Saved custom route checks passed.")
    }
}
