#!/usr/bin/env python3
"""Exercise the production coordinator and route loop with a fake native device."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
fakes = r'''
import Foundation
import Network
import MapKit

@MainActor final class UIApplication {
    static let shared = UIApplication()
    enum State { case active, background }
    var applicationState = State.active
    func open(_ url: URL, completionHandler: @escaping (Bool) -> Void) { completionHandler(true) }
}
@MainActor final class BackgroundLocationKeepAlive {
    var started = false
    var starts = 0
    var stops = 0
    func start() { started = true; starts += 1 }
    func stop() { started = false; stops += 1 }
}
enum BuildEdition { static let callbackScheme = "wrappin" }
enum TunnelHandoffApp { case localDevVPN; var launchURL: URL { URL(string: "localdevvpn://")! } }
enum TunnelHandoffPolicy {
    static func offersMobileDataWorkaround(for app: TunnelHandoffApp) -> Bool { true }
    static func recommendsWiFiWhenUnavailable(for app: TunnelHandoffApp) -> Bool { false }
    static func requiresLocalDevVPNCellularHandoff(app: TunnelHandoffApp, isWiFiPathKnown: Bool, isWiFiSatisfied: Bool) -> Bool { false }
}
enum UsageAnalyticsEvent { case connectionHelpShown, connectionRetrySelected, connectionRetrySucceeded }
struct ConnectionRetryTelemetry {
    mutating func reset() {}
    mutating func selected() -> UsageAnalyticsEvent { .connectionRetrySelected }
    mutating func becameActive() -> UsageAnalyticsEvent? { nil }
}
enum FailureDisposition { case terminal, recoverable }
enum SchedulerFailureReason { case unknown }
enum RouteMode { case walking, driving }
@MainActor final class AppModel {
    enum PairingStatus { case paired }
    let pairingStatus = PairingStatus.paired
    let deviceSession = LocalDeviceSessionCoordinator()
    func startRouteLocationSession(at: LocationTarget, destination: LocationTarget,
        mode: RouteMode, coordinateMode: FixedCoordinateMode, speedMetresPerSecond: Double) async {
        preconditionFailure("Route startup is outside this device-boundary fixture")
    }
}

typealias WPLocationStartedCallback = @convention(c) (UnsafeMutableRawPointer?) -> Void
struct WPLocationResult {
    var error_message: UnsafeMutablePointer<CChar>?
    var error_stage: Int32 = 0
    var error_is_recoverable: Int32 = 0
    var error_detail: UnsafeMutablePointer<CChar>?
}
// Only the device boundary is faked. Production scheduling, cancellation,
// error handling and route progression execute unchanged.
enum FakeDevice {
    static let condition = NSCondition()
    static var nextID = 100
    static var runs: [SimulationCoordinates] = []
    static var failures: [Int32] = []
    static var cancelled: Set<Int> = []
    static var count: Int {
        condition.lock(); defer { condition.unlock() }
        return runs.count
    }
    static var lastCoordinates: SimulationCoordinates? {
        condition.lock(); defer { condition.unlock() }
        return runs.last
    }
    static func setFailures(_ stages: [Int32]) {
        condition.lock(); defer { condition.unlock() }
        failures = stages
    }
}
func wp_location_session_create() -> OpaquePointer? {
    FakeDevice.condition.lock(); defer { FakeDevice.condition.unlock() }
    FakeDevice.nextID += 1
    return OpaquePointer(bitPattern: FakeDevice.nextID)
}
func wp_location_session_cancel(_ session: OpaquePointer) {
    FakeDevice.condition.lock(); defer { FakeDevice.condition.unlock() }
    FakeDevice.cancelled.insert(Int(bitPattern: session))
    FakeDevice.condition.broadcast()
}
func wp_location_session_destroy(_ session: OpaquePointer) {}
func wp_location_result_destroy(_ result: UnsafeMutablePointer<WPLocationResult>) {}
func wp_location_session_update(_ session: OpaquePointer, _ lat: Double, _ lon: Double) -> Int32 { 0 }
func wp_pairing_record_matches_service(_ bytes: UnsafePointer<UInt8>, _ count: Int, _ identifier: UnsafePointer<CChar>, _ tag: UnsafePointer<CChar>) -> Int32 { 1 }
func wp_location_session_run(
    _ session: OpaquePointer, _ record: UnsafePointer<UInt8>, _ length: Int,
    _ peer: UnsafePointer<CChar>, _ port: UInt16, _ identifier: UnsafePointer<CChar>,
    _ tag: UnsafePointer<CChar>, _ lat: Double, _ lon: Double,
    _ callback: WPLocationStartedCallback?, _ context: UnsafeMutableRawPointer,
    _ result: UnsafeMutablePointer<WPLocationResult>
) -> Int32 {
    FakeDevice.condition.lock()
    FakeDevice.runs.append(SimulationCoordinates(latitude: lat, longitude: lon))
    if !FakeDevice.failures.isEmpty {
        result.pointee.error_stage = FakeDevice.failures.removeFirst()
        result.pointee.error_is_recoverable = 1
        FakeDevice.condition.unlock()
        return 1
    }
    FakeDevice.condition.unlock()
    callback?(context)
    FakeDevice.condition.lock()
    while !FakeDevice.cancelled.contains(Int(bitPattern: session)) {
        FakeDevice.condition.wait()
    }
    FakeDevice.condition.unlock()
    return 0 // Acknowledged clear after the coordinator requests stop.
}
'''

checks = r'''
extension LocalDeviceSessionCoordinator {
    fileprivate static func fixture(automatic: Bool = true) -> LocalDeviceSessionCoordinator {
        let session = LocalDeviceSessionCoordinator()
        let target = LocationTarget(name: "Point", subtitle: "", latitude: 1, longitude: 2)
        session.pendingSession = PendingSession(
            pairingRecord: Data([1]), target: target,
            simulationCoordinates: SimulationCoordinates(latitude: 10, longitude: 20)
        )
        session.resolvedService = RemotePairingService(
            host: "127.0.0.1", port: 12345, identifier: "fixture", authTag: "fixture",
            endpointSource: .discovered, fallbackHost: nil
        )
        session.automaticReconnectEnabled = automatic
        session.workerIsRunning = true
        session.activeSession = OpaquePointer(bitPattern: 1)
        session.activeRunIdentifier = UUID()
        session.nativeLocationStarted()
        return session
    }

    fileprivate func finishWithFailure(stage: FailureStage, code: Int32, recoverable: Bool = false) {
        let run = activeRunIdentifier!
        nativeLocationFinished(.failure(NativeLocationFailure(
            message: "Injected connection failure", stage: stage, isRecoverable: recoverable,
            wasCancelled: false, detail: "fixture"
        )), runIdentifier: run)
    }
}

extension WalkingSimulationController {
    fileprivate func configureFixture(using session: LocalDeviceSessionCoordinator) {
        routePoints = [MKMapPoint(CLLocationCoordinate2D(latitude: 0, longitude: 0)),
                       MKMapPoint(CLLocationCoordinate2D(latitude: 0, longitude: 0.01))]
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last!
        destination = LocationTarget(name: "Destination", subtitle: "", latitude: 0, longitude: 0.01)
        phase = .walking
        beginMovement(using: session)
    }
}

extension LocalDeviceSessionCoordinator {
    @MainActor static func eventually(_ condition: () -> Bool, seconds: Double = 3) async {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() && Date() < deadline { try! await Task.sleep(for: .milliseconds(20)) }
        precondition(condition(), "async condition did not become true")
    }

    @MainActor static func runContinuityChecks() async {
        // The old native run fails; a fresh run reuses the *latest transformed*
        // coordinate, keeps the background request, and reaches active again.
        let resumed = LocalDeviceSessionCoordinator.fixture()
        let originalStarts = FakeDevice.count
        resumed.finishWithFailure(stage: .locationActiveWrite, code: 12)
        precondition(resumed.isReconnecting && resumed.phase == .connecting)
        precondition(resumed.backgroundKeepAlive.started && resumed.automaticReconnectAttempt == 1)
        await eventually({ !resumed.isReconnecting && resumed.workerIsRunning })
        precondition(FakeDevice.count == originalStarts + 1)
        precondition(FakeDevice.lastCoordinates == SimulationCoordinates(latitude: 10, longitude: 20))
        resumed.stop()
        await eventually({ resumed.phase == .idle })
        precondition(resumed.didConfirmLocationClear && !resumed.backgroundKeepAlive.started)

        // Stop and reset while the backoff task is queued; no native run may
        // escape cancellation and resurrect the session afterwards.
        for reset in [false, true] {
            let queued = LocalDeviceSessionCoordinator.fixture()
            queued.finishWithFailure(stage: .locationActiveWrite, code: 12)
            let before = FakeDevice.count
            if reset { queued.reset() } else { queued.stop() }
            try! await Task.sleep(for: .milliseconds(1100))
            precondition(FakeDevice.count == before && queued.phase == .idle)
            precondition(!queued.isReconnecting && queued.pendingSession == nil)
        }

        // Restoring real location is never an automatic-resume operation.
        let restore = LocalDeviceSessionCoordinator.fixture(automatic: false)
        restore.finishWithFailure(stage: .locationActiveWrite, code: 12)
        guard case .failed = restore.phase else { preconditionFailure("restore must terminate") }
        precondition(!restore.isReconnecting && restore.reconnectTask == nil)

        let auth = LocalDeviceSessionCoordinator.fixture()
        auth.finishWithFailure(stage: .pairVerification, code: 4)
        precondition(!auth.isReconnecting && auth.pendingSession == nil)

        // Stop was already requested when the native failure arrived.
        let stopping = LocalDeviceSessionCoordinator.fixture()
        stopping.stop()
        stopping.finishWithFailure(stage: .locationActiveWrite, code: 12)
        precondition(!stopping.isReconnecting && stopping.pendingSession == nil)

        // Failed reconnects use a bounded budget even when the native engine
        // calls a setup error recoverable. No fallback into an unbounded loop.
        FakeDevice.setFailures([3, 3, 3])
        let exhausted = LocalDeviceSessionCoordinator.fixture()
        let beforeExhaustion = FakeDevice.count
        exhausted.finishWithFailure(stage: .locationActiveWrite, code: 12)
        await eventually({
            if case .failed = exhausted.phase { return true }
            return false
        }, seconds: 10)
        precondition(FakeDevice.count == beforeExhaustion + 3)
        precondition(exhausted.automaticReconnectAttempt == 3 && !exhausted.backgroundKeepAlive.started)
        precondition(exhausted.pendingSession == nil && !exhausted.isReconnecting)

        // Route time freezes during reconnect, then resumes without counting
        // the disconnected interval. A user pause also survives recovery.
        let routeSession = LocalDeviceSessionCoordinator.fixture()
        routeSession.isReconnecting = true
        let route = WalkingSimulationController()
        route.configureFixture(using: routeSession)
        try! await Task.sleep(for: .milliseconds(1200))
        precondition(route.distanceTravelled == 0 && route.phase == .walking)
        routeSession.isReconnecting = false
        await eventually({ route.distanceTravelled > 0 })
        precondition(route.distanceTravelled < 2.5)
        route.togglePause()
        routeSession.isReconnecting = true
        try! await Task.sleep(for: .milliseconds(1100))
        precondition(route.phase == .paused)
        route.reset()
        routeSession.workerIsRunning = false
        routeSession.clearPendingSession()
        print("Production coordinator: fresh reconnect, coordinates, stop/reset cancellation, restore/auth exclusions and retry exhaustion passed")
        print("Production route loop: reconnect freeze, resumed progress and user pause passed")
    }
}

@main struct ContinuityCheck {
    @MainActor static func main() async {
        await LocalDeviceSessionCoordinator.runContinuityChecks()
    }
}
'''

paths = [
    'WrapPin/Models/LocationTarget.swift',
    'WrapPin/Services/FixedCoordinateMode.swift',
    'WrapPin/Services/FailureStage.swift',
    'WrapPin/Services/LocationSessionReconnectPolicy.swift',
    'WrapPin/Services/Tunnel/NetServiceEndpointResolver.swift',
    'WrapPin/Services/Tunnel/LocalDeviceSessionCoordinator.swift',
    'WrapPin/Features/Map/RouteHitTesting.swift',
    'WrapPin/Features/Map/WalkingSimulationController.swift',
]
sources = '\n'.join((root / path).read_text() for path in paths)
for imported in ['import WrapPinPairingFFI\n', 'import UIKit\n', 'import Observation\n']:
    sources = sources.replace(imported, '')
sources = sources.replace('@Observable\n', '').replace('@ObservationIgnored\n', '')
with tempfile.TemporaryDirectory() as directory:
    temporary = Path(directory)
    swift = temporary / 'continuity.swift'
    binary = temporary / 'continuity'
    swift.write_text(fakes + sources + checks)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', str(temporary / 'cache'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=30)
