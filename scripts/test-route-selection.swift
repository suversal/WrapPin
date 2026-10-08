import MapKit

// Compile with the production RouteHitTesting.swift to verify which previewed
// route a map tap selects.
@main
struct RouteSelectionCheck {
    static func main() {
        let north = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 100, y: 0), MKMapPoint(x: 200, y: 0)]
        let south = [MKMapPoint(x: 0, y: 0), MKMapPoint(x: 100, y: 60), MKMapPoint(x: 200, y: 0)]
        let routes = [north, south]

        // A tap beside one route selects that route.
        precondition(RouteHitTesting.nearestRouteIndex(to: MKMapPoint(x: 100, y: 5), in: routes, tolerance: 10) == 0)
        precondition(RouteHitTesting.nearestRouteIndex(to: MKMapPoint(x: 100, y: 55), in: routes, tolerance: 10) == 1)
        // Between two routes the closer one wins.
        precondition(RouteHitTesting.nearestRouteIndex(to: MKMapPoint(x: 100, y: 20), in: routes, tolerance: 40) == 0)
        // Away from every route nothing is selected, so the tap can drop a pin.
        precondition(RouteHitTesting.nearestRouteIndex(to: MKMapPoint(x: 100, y: 200), in: routes, tolerance: 10) == nil)
        // Distance is measured to the segment, not only to its vertices.
        precondition(RouteHitTesting.distance(from: MKMapPoint(x: 50, y: 3), to: north) == 3)
        // Beyond the end of a route the distance is to its last point.
        precondition(RouteHitTesting.distance(from: MKMapPoint(x: 203, y: 4), to: north) == 5)
        // Degenerate input never crashes or matches by accident.
        precondition(RouteHitTesting.distance(from: MKMapPoint(x: 0, y: 0), to: []) == nil)
        precondition(RouteHitTesting.distance(from: MKMapPoint(x: 3, y: 4), to: [MKMapPoint(x: 0, y: 0)]) == 5)
        precondition(RouteHitTesting.nearestRouteIndex(to: MKMapPoint(x: 0, y: 0), in: [], tolerance: 10) == nil)

        print("Route selection checks passed")
    }
}
