import CoreLocation
import Foundation
import MapKit

// Compile with the production planner, controller, GPX parser, route geometry,
// MapKitCompatibility, recovery model, coordinate transform and LocationTarget. Only the device
// transport is replaced, so these checks never contact a device or server.
enum TestPairingStatus { case paired, notPaired }
enum DeviceSessionPhase: Equatable {
    case idle, active, stopping, openingLocalDevVPN, discovering, connecting, failed(String)
}
@MainActor
final class LocalDeviceSessionCoordinator {
    enum UpdateResult { case updated }
    var phase: DeviceSessionPhase = .idle
    var isReconnecting = false
    var updates: [SimulationCoordinates] = []
    func updateLocation(_ target: LocationTarget, simulationCoordinates: SimulationCoordinates) -> UpdateResult {
        updates.append(simulationCoordinates)
        return .updated
    }
    func stop() { phase = .stopping }
}
@MainActor
final class AppModel {
    var pairingStatus = TestPairingStatus.paired
    let deviceSession = LocalDeviceSessionCoordinator()
    var savedPoints: [SavedRoutePoint]?
    var nextPointIndex: Int?
    var capturedMode: RouteMode?
    var capturedSpeed: Double?
    func startRouteLocationSession(at: LocationTarget, destination: LocationTarget, mode: RouteMode,
                                   coordinateMode: FixedCoordinateMode, speedMetresPerSecond: Double,
                                   customRoutePoints: [SavedRoutePoint]?) async {
        savedPoints = customRoutePoints
        capturedMode = mode
        capturedSpeed = speedMetresPerSecond
        deviceSession.phase = .active
    }
    func recordCustomRouteProgress(nextPointIndex: Int, at: LocationTarget) { self.nextPointIndex = nextPointIndex }
}

@main
struct CustomRouteChecks {
    static func parse(_ xml: String) throws -> [GPXRouteSegment] {
        try GPXRouteParser.parse(Data(xml.utf8))
    }
    static func expectFailure(_ operation: () throws -> Void) {
        do { try operation(); fatalError("Expected invalid route to fail") }
        catch { precondition(error is GPXRouteError) }
    }
    @MainActor
    static func main() async throws {
        let pointA = CLLocationCoordinate2D(latitude: 24.7, longitude: 46.7)
        let pointB = CLLocationCoordinate2D(latitude: 24.7001, longitude: 46.7)
        let pointC = CLLocationCoordinate2D(latitude: 24.7001, longitude: 46.7001)
        let route = try SimulationRoute(coordinates: [pointA, pointB, pointC], name: "Saudi test")
        precondition(route.isCustom && route.distance > 15 && route.distance < 30)
        expectFailure { _ = try SimulationRoute(coordinates: [pointA], name: "") }
        expectFailure { _ = try SimulationRoute(coordinates: [pointA, pointA], name: "") }
        expectFailure { _ = try SimulationRoute(coordinates: [pointA, .init(latitude: .nan, longitude: 0)], name: "") }
        let dateLine = try SimulationRoute(coordinates: [.init(latitude: 0, longitude: 179.999), .init(latitude: 0, longitude: -179.999)], name: "Date line")
        precondition(dateLine.distance > 200 && dateLine.distance < 250)
        precondition(abs(dateLine.mapPoints[1].x - dateLine.mapPoints[0].x) < 2000)
        precondition(dateLine.mapPoints.allSatisfy { CLLocationCoordinate2DIsValid($0.coordinate) })

        let track = "<gpx xmlns='http://www.topografix.com/GPX/1/1'><trk><trkseg><trkpt lat='24.7' lon='46.7'/><trkpt lat='24.8' lon='46.8'/></trkseg><trkseg><trkpt lat='25' lon='47'/><trkpt lat='26' lon='48'/></trkseg></trk></gpx>"
        let split = try parse(track)
        precondition(split.count == 2 && split[0].coordinates.count == 2 && split[1].coordinates[0].latitude == 25)
        let gpxRoute = try parse("<gpx><rte><rtept lat='0' lon='0'/><rtept lat='0' lon='1'/></rte></gpx>")
        precondition(gpxRoute.count == 1)
        expectFailure { _ = try parse("<gpx><trk><trkseg><trkpt lat='91' lon='0'/><trkpt lat='0' lon='0'/></trkseg></trk></gpx>") }
        expectFailure { _ = try parse("<gpx><wpt lat='0' lon='0'/><wpt lat='1' lon='1'/></gpx>") }
        expectFailure { _ = try parse("<gpx><trk>") }
        expectFailure { _ = try parse("<!DOCTYPE gpx [<!ENTITY x 'test'>]><gpx>&x;</gpx>") }
        expectFailure { _ = try parse("<!DOCTYPE gpx [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><gpx>&x;</gpx>") }
        expectFailure { _ = try GPXRouteParser.parse(Data(repeating: 32, count: GPXRouteParser.maximumFileSize + 1)) }
        expectFailure { _ = try parse("<gpx><rte>" + String(repeating: "<rtept lat='0' lon='0'/>", count: GPXRouteParser.maximumPointCount + 1) + "</rte></gpx>") }
        let planner = WalkingRoutePlanner()
        _ = try planner.previewCustomRoute(coordinates: [pointA, pointB, pointC], name: "Test")
        precondition(planner.routes.count == 1 && planner.destination?.latitude == pointC.latitude)
        precondition(!planner.isLoading && planner.errorMessage == nil)

        let simulation = WalkingSimulationController()
        let model = AppModel()
        let destination = planner.destination!
        simulation.prepare(route: route, destination: destination, coordinateMode: .wgs84)
        simulation.customWalkingSpeedKilometresPerHour = 5
        precondition(abs(simulation.speedMetresPerSecond - 5 / 3.6) < 0.00001)
        await simulation.start(using: model)
        precondition(model.savedPoints?.count == 3)
        simulation.handleDeviceSessionPhase(.active, deviceSession: model.deviceSession, appModel: model)
        try await Task.sleep(for: .milliseconds(1150))
        precondition(simulation.distanceTravelled > 0 && !model.deviceSession.updates.isEmpty)
        simulation.togglePause()
        let pausedDistance = simulation.distanceTravelled
        try await Task.sleep(for: .milliseconds(1100))
        precondition(simulation.distanceTravelled == pausedDistance)
        simulation.togglePause()
        model.deviceSession.isReconnecting = true
        try await Task.sleep(for: .milliseconds(1100))
        precondition(simulation.distanceTravelled == pausedDistance)
        model.deviceSession.isReconnecting = false
        try await Task.sleep(for: .milliseconds(1100))
        precondition(simulation.distanceTravelled > pausedDistance && model.nextPointIndex != nil)
        simulation.stop(using: model.deviceSession)
        precondition(simulation.phase == .stopping && model.deviceSession.phase == .stopping)
        simulation.handleDeviceSessionPhase(.idle, deviceSession: model.deviceSession, appModel: model)
        precondition(simulation.phase == .idle && simulation.currentCoordinate == nil)
        simulation.reset()

        // Custom geometry must preserve driving speeds above walking limits.
        let longEnd = CLLocationCoordinate2D(latitude: 24.8, longitude: 46.7)
        let drive = try planner.previewCustomRoute(coordinates: [pointA, longEnd], name: "Drive", mode: .driving)
        precondition(planner.mode == .driving)
        let driver = WalkingSimulationController()
        let driveModel = AppModel()
        driver.prepare(route: drive, destination: planner.destination!, mode: .driving, coordinateMode: .wgs84)
        driver.customRouteSpeedKilometresPerHour = 72
        precondition(abs(driver.speedMetresPerSecond - 20) < 0.00001)
        await driver.start(using: driveModel)
        precondition(driveModel.capturedMode == .driving && driveModel.capturedSpeed == 20)
        driver.handleDeviceSessionPhase(.active, deviceSession: driveModel.deviceSession, appModel: driveModel)
        try await Task.sleep(for: .milliseconds(1150))
        precondition(driver.distanceTravelled > 10 && driver.distanceTravelled < 50)
        driver.stop(using: driveModel.deviceSession)
        driver.customRouteSpeedKilometresPerHour = 0.1
        precondition(abs(driver.speedMetresPerSecond - 0.1 / 3.6) < 0.00001)
        driver.customRouteSpeedKilometresPerHour = 240
        precondition(abs(driver.speedMetresPerSecond - 240 / 3.6) < 0.00001)
        driver.customRouteSpeedKilometresPerHour = .nan
        precondition(driver.speedMetresPerSecond.isFinite)

        // A very short route reaches its exact final coordinate, then reverses locally.
        let tinyEnd = CLLocationCoordinate2D(latitude: 24.700002, longitude: 46.7)
        let tinyRoute = try SimulationRoute(coordinates: [pointA, tinyEnd], name: "Tiny")
        let tinyDestination = LocationTarget(name: "End", subtitle: "", latitude: tinyEnd.latitude, longitude: tinyEnd.longitude)
        simulation.prepare(route: tinyRoute, destination: tinyDestination, coordinateMode: .wgs84, startName: "Tiny start")
        await simulation.start(using: model)
        simulation.handleDeviceSessionPhase(.active, deviceSession: model.deviceSession, appModel: model)
        try await Task.sleep(for: .milliseconds(1100))
        precondition(simulation.phase == .arrived && simulation.currentCoordinate?.latitude == tinyEnd.latitude)
        let returnedStart = simulation.prepareReturnTrip()
        precondition(returnedStart?.name == "Tiny start")
        precondition(abs((returnedStart?.latitude ?? 0) - pointA.latitude) < 0.00000001)
        precondition(simulation.phase == .idle)
        simulation.reset()
        print("Custom routes: local geometry, date line, GPX segments, invalid input, bounds, movement, pause, reconnect, stop, arrival and return passed")
    }
}
