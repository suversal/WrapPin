import CoreLocation
import Foundation
import MapKit

@main
struct RoutePointSearchChecks {
    @MainActor static func item(_ name: String, _ latitude: Double, _ longitude: Double) -> MKMapItem {
        let item = MapKitCompatibility.mapItem(at: .init(latitude: latitude, longitude: longitude))
        item.name = name
        return item
    }

    @MainActor static func main() async {
        let start = LocationTarget(name: "Start", subtitle: "Start address", latitude: 31.2, longitude: 121.4)
        let end = LocationTarget(name: "End", subtitle: "End address", latitude: 31.3, longitude: 121.5)
        let via = LocationTarget(name: "Park", subtitle: "Park address", latitude: 31.25, longitude: 121.45)
        var points: [RouteWaypoint] = []
        precondition(RoutePointRole.start.apply(start, to: &points, limit: 4))
        precondition(RoutePointRole.destination.apply(end, to: &points, limit: 4))
        let endID = points.last!.id
        precondition(RoutePointRole.waypoint.apply(via, to: &points, limit: 4))
        precondition(points.map(\.name) == ["Start", "Park", "End"] && points.last?.id == endID)
        let beforeReplacement = points
        let viaID = points[1].id
        precondition(RoutePointRole.replace(viaID).apply(start, to: &points, limit: 3))
        precondition(points[1].name == "Start" && points[1].id == viaID)
        precondition(points != beforeReplacement, "Same-ID replacement must trigger the editor's geometry update")
        precondition(!RoutePointRole.waypoint.apply(via, to: &points, limit: 3))
        precondition(!RoutePointRole.replace(UUID()).apply(via, to: &points, limit: 4))
        precondition(RoutePointRole.destination.apply(via, to: &points, limit: 3))
        precondition(points.last?.id == endID && points.last?.address == "Park address")
        points = [RouteWaypoint(target: start)]
        precondition(RoutePointRole.waypoint.apply(via, to: &points, limit: 4))
        precondition(points.first?.name == "Start" && points.last?.name == "Park")

        // Actual production search publishes all candidates for the route picker,
        // keeps the main map's first-result behavior, and ignores stale completions.
        let first = item("Place A", 31.2, 121.4)
        let second = item("Place B", 31.3, 121.5)
        var receivedRegion = false
        let candidates = MapViewModel(selectsFirstSearchResult: false, enablesSearchSuggestions: false) { request in
            receivedRegion = request.region.center.latitude == 31.2
            return [first, second, first]
        }
        candidates.setOverseasSearch(false)
        candidates.searchRegion = MKCoordinateRegion(center: start.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        candidates.updateSearchQuery("museum")
        await candidates.search()
        precondition(receivedRegion && candidates.searchResults.map(\.name) == ["Place A", "Place B"])
        precondition(candidates.selectedLocation == nil && !candidates.isSearching)
        candidates.updateSearchQuery("31.2, 121.4")
        await candidates.search()
        precondition(candidates.searchResults.count == 1 && candidates.searchResults[0].latitude == 31.2)
        candidates.clearSearch()
        precondition(candidates.searchResults.isEmpty)

        let mainMap = MapViewModel(selectsFirstSearchResult: true, enablesSearchSuggestions: false) { _ in [first, second] }
        mainMap.updateSearchQuery("museum")
        await mainMap.search()
        precondition(mainMap.selectedLocation?.name == "Place A" && mainMap.searchResults.isEmpty)

        var pending: [String: CheckedContinuation<[MKMapItem], Error>] = [:]
        let racing = MapViewModel(selectsFirstSearchResult: false, enablesSearchSuggestions: false) { request in
            try await withCheckedThrowingContinuation { pending[request.naturalLanguageQuery!] = $0 }
        }
        racing.updateSearchQuery("old")
        let old = Task { await racing.search() }
        while pending["old"] == nil { await Task.yield() }
        racing.updateSearchQuery("new")
        let newer = Task { await racing.search() }
        while pending["new"] == nil { await Task.yield() }
        pending["new"]!.resume(returning: [second])
        await newer.value
        pending["old"]!.resume(returning: [first])
        await old.value
        precondition(racing.searchResults.map(\.name) == ["Place B"] && !racing.isSearching)
        racing.updateSearchQuery("cancel")
        let cancelled = Task { await racing.search() }
        while pending["cancel"] == nil { await Task.yield() }
        racing.clearSearch()
        pending["cancel"]!.resume(throwing: NSError(domain: "test", code: 1))
        await cancelled.value
        precondition(racing.searchResults.isEmpty && racing.errorMessage == nil && !racing.isSearching)
        racing.updateSearchQuery("empty")
        let empty = Task { await racing.search() }
        while pending["empty"] == nil { await Task.yield() }
        pending["empty"]!.resume(returning: [])
        await empty.value
        let errorMessage = racing.errorMessage
        precondition(errorMessage != nil)
        try? await Task.sleep(for: .seconds(5))
        precondition(racing.errorMessage == errorMessage, "Picker errors must remain until the next edit")
        racing.updateSearchQuery("retry")
        precondition(racing.errorMessage == nil)
        print("Route point search: named stops, insert-before-destination, replacement, limits, candidates, coordinates, region, main-map compatibility, stale replies and cancellation passed")
    }
}
