import MapKit

/// Geometry shared by Apple directions, hand-drawn routes and imported GPX.
struct SimulationRoute {
    let polyline: MKPolyline
    let distance: CLLocationDistance
    let name: String
    let isCustom: Bool

    var mapPoints: [MKMapPoint] {
        let points = polyline.points()
        return (0..<polyline.pointCount).map { points[$0] }
    }

    init(_ route: MKRoute) {
        polyline = route.polyline
        distance = route.distance
        name = route.name
        isCustom = false
    }

    init(coordinates: [CLLocationCoordinate2D], name: String) throws {
        guard coordinates.count >= 2, coordinates.count <= GPXRouteParser.maximumPointCount,
              coordinates.allSatisfy(CLLocationCoordinate2DIsValid) else {
            throw GPXRouteError.invalidPoints
        }
        // Unwrap longitude at the date line so interpolation takes the short path.
        var points: [MKMapPoint] = []
        let worldWidth = MKMapRect.world.size.width
        for coordinate in coordinates {
            var point = MKMapPoint(coordinate)
            if let previous = points.last {
                point.x += ((previous.x - point.x) / worldWidth).rounded() * worldWidth
            }
            points.append(point)
        }
        let length = zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
        guard length.isFinite, length > 0.1 else { throw GPXRouteError.invalidPoints }
        polyline = MKPolyline(points: points, count: points.count)
        distance = length
        self.name = name
        isCustom = true
    }
}
