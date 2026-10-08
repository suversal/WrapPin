import CoreLocation
import MapKit
import Observation

enum RouteMode: String, Codable, CaseIterable, Identifiable {
    case walking
    case driving

    var id: Self { self }
    var transportType: MKDirectionsTransportType {
        self == .walking ? .walking : .automobile
    }
    var title: String {
        self == .walking ? String(localized: "Walking route") : String(localized: "Driving route")
    }
    var symbol: String { self == .walking ? "figure.walk" : "car.fill" }
}

@MainActor
@Observable
final class WalkingRoutePlanner {
    /// The suggested route first, then up to two alternatives.
    private(set) var routes: [MKRoute] = []
    private(set) var selectedRouteIndex = 0
    private(set) var destination: LocationTarget?
    private(set) var mode: RouteMode = .walking
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var directions: MKDirections?

    private static let maximumRouteCount = 3

    var route: MKRoute? {
        routes.indices.contains(selectedRouteIndex) ? routes[selectedRouteIndex] : nil
    }

    func preview(
        to target: LocationTarget,
        from source: LocationTarget? = nil,
        mode: RouteMode = .walking,
        includingAlternatives: Bool = true
    ) async -> MKRoute? {
        directions?.cancel()
        routes = []
        selectedRouteIndex = 0
        destination = target
        self.mode = mode
        errorMessage = nil
        isLoading = true

        let request = MKDirections.Request()
        if let source {
            request.source = MKMapItem(
                location: CLLocation(latitude: source.latitude, longitude: source.longitude),
                address: nil
            )
        } else {
            request.source = .forCurrentLocation()
        }
        request.destination = MKMapItem(
            location: CLLocation(latitude: target.latitude, longitude: target.longitude),
            address: nil
        )
        request.transportType = mode.transportType
        request.requestsAlternateRoutes = includingAlternatives

        let calculation = MKDirections(request: request)
        directions = calculation

        defer {
            if directions === calculation {
                directions = nil
                isLoading = false
            }
        }

        do {
            let response = try await calculation.calculate()
            guard directions === calculation else { return nil }
            guard let preferredRoute = response.routes.first else {
                errorMessage = mode == .walking
                    ? String(localized: "No walking route was found for this destination.")
                    : String(localized: "No driving route was found for this destination.")
                return nil
            }

            routes = Array(response.routes.prefix(Self.maximumRouteCount))
            return preferredRoute
        } catch is CancellationError {
            return nil
        } catch {
            guard directions === calculation else { return nil }
            errorMessage = mode == .walking
                ? String(localized: "Walking directions are unavailable. Check Location access and your internet connection, then try again.")
                : String(localized: "Driving directions are unavailable. Check Location access and your internet connection, then try again.")
            return nil
        }
    }

    func clear() {
        directions?.cancel()
        directions = nil
        routes = []
        selectedRouteIndex = 0
        destination = nil
        mode = .walking
        isLoading = false
        errorMessage = nil
    }

    @discardableResult
    func selectRoute(at index: Int) -> MKRoute? {
        guard routes.indices.contains(index) else { return nil }
        selectedRouteIndex = index
        return routes[index]
    }

    /// Once a route is in use the other suggestions no longer apply.
    func discardAlternativeRoutes() {
        guard let route, routes.count > 1 else { return }
        routes = [route]
        selectedRouteIndex = 0
    }

    func retargetExistingRoute(to target: LocationTarget) {
        guard route != nil else { return }
        discardAlternativeRoutes()
        destination = target
        errorMessage = nil
    }
}
