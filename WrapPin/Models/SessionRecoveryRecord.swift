import Foundation

struct SessionRecoveryRecord: Codable, Equatable {
    enum Kind: String, Codable {
        case fixedLocation
        case walkingRoute
        case drivingRoute
    }

    var kind: Kind
    var lastReportedLocation: LocationTarget
    var destination: LocationTarget?
    // Kept under its original persisted name for backward compatibility.
    // The selected mode now applies to fixed, walking, and driving sessions.
    var fixedCoordinateMode: FixedCoordinateMode?
    var walkingPaceMetresPerSecond: Double?
    var routeSpeedMetresPerSecond: Double?
    // Optional so records written before custom routes remain decodable.
    var customRoutePoints: [SavedRoutePoint]?
    var nextCustomRoutePointIndex: Int?
    let startedAt: Date
    var updatedAt: Date

    var isRoute: Bool {
        (kind == .walkingRoute || kind == .drivingRoute) && destination != nil
    }

    var routeMode: RouteMode {
        kind == .drivingRoute ? .driving : .walking
    }

    var savedRouteSpeed: Double? {
        routeSpeedMetresPerSecond ?? walkingPaceMetresPerSecond
    }

    static func fixed(
        at target: LocationTarget,
        mode: FixedCoordinateMode
    ) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: .fixedLocation,
            lastReportedLocation: target,
            destination: nil,
            fixedCoordinateMode: mode,
            walkingPaceMetresPerSecond: nil,
            routeSpeedMetresPerSecond: nil,
            startedAt: .now,
            updatedAt: .now
        )
    }

    static func route(
        from start: LocationTarget,
        to destination: LocationTarget,
        mode: RouteMode,
        coordinateMode: FixedCoordinateMode,
        speedMetresPerSecond: Double
    ) -> SessionRecoveryRecord {
        SessionRecoveryRecord(
            kind: mode == .walking ? .walkingRoute : .drivingRoute,
            lastReportedLocation: start,
            destination: destination,
            fixedCoordinateMode: coordinateMode,
            walkingPaceMetresPerSecond: nil,
            routeSpeedMetresPerSecond: speedMetresPerSecond,
            startedAt: .now,
            updatedAt: .now
        )
    }
}

struct SavedRoutePoint: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}
