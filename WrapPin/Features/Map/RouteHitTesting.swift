import MapKit

/// Finds which previewed route a map tap landed on. Works in map points so it
/// does not depend on the view; the caller supplies the tolerance that matches
/// a comfortable touch target at the current zoom.
enum RouteHitTesting {
    static func nearestRouteIndex(
        to point: MKMapPoint,
        in routes: [[MKMapPoint]],
        tolerance: Double
    ) -> Int? {
        var nearest: (index: Int, distance: Double)?
        for (index, route) in routes.enumerated() {
            guard let distance = distance(from: point, to: route), distance <= tolerance else { continue }
            if nearest == nil || distance < nearest!.distance {
                nearest = (index, distance)
            }
        }
        return nearest?.index
    }

    static func distance(from point: MKMapPoint, to route: [MKMapPoint]) -> Double? {
        guard var previous = route.first else { return nil }
        var shortest = hypot(point.x - previous.x, point.y - previous.y)
        for next in route.dropFirst() {
            shortest = min(shortest, distance(from: point, toSegmentFrom: previous, to: next))
            previous = next
        }
        return shortest
    }

    private static func distance(
        from point: MKMapPoint,
        toSegmentFrom start: MKMapPoint,
        to end: MKMapPoint
    ) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(point.x - start.x, point.y - start.y) }

        let projection = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let fraction = min(max(projection, 0), 1)
        return hypot(point.x - (start.x + fraction * dx), point.y - (start.y + fraction * dy))
    }
}

extension MKRoute {
    var mapPoints: [MKMapPoint] {
        let points = polyline.points()
        return (0..<polyline.pointCount).map { points[$0] }
    }
}
