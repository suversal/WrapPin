#!/usr/bin/env python3
"""Exercise the production background keep-alive with offline platform fakes."""

from pathlib import Path
import plistlib
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
KEEP_ALIVE = ROOT / "WrapPin/Services/BackgroundLocationKeepAlive.swift"
PAIRING = ROOT / "WrapPin/Services/Pairing/OnDevicePairingCoordinator.swift"
SESSION = ROOT / "WrapPin/Services/Tunnel/LocalDeviceSessionCoordinator.swift"
INFO = ROOT / "Configuration/WrapPin-Info.plist"


def method_block(source: str, marker: str) -> str:
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        depth += (source[index] == "{") - (source[index] == "}")
        if depth == 0:
            return source[start:index + 1]
    raise AssertionError(f"unterminated block: {marker}")


keep_alive = KEEP_ALIVE.read_text(encoding="utf-8")
keep_alive = (
    keep_alive
    .replace("import CoreLocation\n", "")
    .replace("import Observation\n", "")
    .replace("import UIKit\n", "")
    .replace("@Observable\n", "")
    .replace("@preconcurrency ", "")
)

fakes = r'''
import Foundation
@MainActor final class UIApplication {
    enum State { case active, background }
    static let shared = UIApplication()
    var applicationState = State.active
}
let kCLLocationAccuracyKilometer = 1000.0
let kCLDistanceFilterNone = -1.0
enum CLAuthorizationStatus {
    case notDetermined, denied, restricted, authorizedAlways, authorizedWhenInUse
}
struct CLLocation {}
struct CLError: Error {
    enum Code { case locationUnknown, denied, other }
    let code: Code
}
protocol CLLocationManagerDelegate: AnyObject {}
final class CLLocationManager {
    weak var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy = 0.0
    var distanceFilter = 0.0
    var pausesLocationUpdatesAutomatically = true
    var showsBackgroundLocationIndicator = false
    var allowsBackgroundLocationUpdates = false
    var authorizationStatus = CLAuthorizationStatus.notDetermined
    static var enabled = true
    static func locationServicesEnabled() -> Bool { enabled }
    var starts = 0
    var stops = 0
    var requests = 0
    var alwaysRequests = 0
    func startUpdatingLocation() { starts += 1 }
    func stopUpdatingLocation() { stops += 1 }
    func requestWhenInUseAuthorization() { requests += 1 }
    func requestAlwaysAuthorization() { alwaysRequests += 1 }
}
'''

checks = r'''
@main struct Tests {
    @MainActor static func main() {
        let manager = CLLocationManager()
        let keepAlive = BackgroundLocationKeepAlive(
            manager: manager,
            hasBackgroundMode: true
        )

        keepAlive.start()
        keepAlive.start()
        precondition(manager.requests == 1)
        precondition(manager.starts == 0)
        precondition(keepAlive.status == .awaitingAuthorization)

        manager.authorizationStatus = .authorizedWhenInUse
        keepAlive.locationManagerDidChangeAuthorization(manager)
        precondition(manager.starts == 1)
        precondition(keepAlive.started)
        precondition(manager.allowsBackgroundLocationUpdates)
        precondition(!manager.pausesLocationUpdatesAutomatically)
        keepAlive.locationManager(manager, didUpdateLocations: [CLLocation()])
        precondition(keepAlive.status == .receivingUpdates)

        keepAlive.locationManager(
            manager,
            didFailWithError: CLError(code: .locationUnknown)
        )
        precondition(keepAlive.started)
        precondition(keepAlive.status == .locationUnavailable)

        let stopsBeforeError = manager.stops
        keepAlive.locationManager(manager, didFailWithError: CLError(code: .other))
        precondition(keepAlive.status == .locationUnavailable)
        precondition(keepAlive.started && manager.allowsBackgroundLocationUpdates)
        precondition(manager.stops == stopsBeforeError)
        keepAlive.locationManager(manager, didUpdateLocations: [CLLocation()])
        precondition(keepAlive.status == .receivingUpdates)

        keepAlive.reconcile()
        precondition(manager.starts == 1) // No duplicate active update request.
        manager.authorizationStatus = .denied
        keepAlive.reconcile() // No authorization callback: reconcile must notice it.
        precondition(!keepAlive.started && !manager.allowsBackgroundLocationUpdates)
        precondition(keepAlive.status == .denied)
        manager.authorizationStatus = .authorizedWhenInUse
        keepAlive.reconcile()
        precondition(keepAlive.started && manager.starts == 2)
        CLLocationManager.enabled = false
        manager.authorizationStatus = .denied
        keepAlive.reconcile()
        precondition(!keepAlive.started && keepAlive.status == .servicesDisabled)
        CLLocationManager.enabled = true
        manager.authorizationStatus = .authorizedWhenInUse
        keepAlive.reconcile()
        precondition(keepAlive.started && manager.starts == 3)

        keepAlive.locationManager(manager, didFailWithError: CLError(code: .denied))
        precondition(!keepAlive.started && !manager.allowsBackgroundLocationUpdates)
        keepAlive.reconcile()
        precondition(keepAlive.started && manager.starts == 4)

        keepAlive.stop()
        precondition(!keepAlive.started)
        precondition(!manager.allowsBackgroundLocationUpdates)
        precondition(keepAlive.status == .stopped)
        keepAlive.reconcile()
        precondition(!keepAlive.started && manager.starts == 4)

        for authorization: CLAuthorizationStatus in [.denied, .restricted] {
            let deniedManager = CLLocationManager()
            deniedManager.authorizationStatus = authorization
            let deniedKeepAlive = BackgroundLocationKeepAlive(
                manager: deniedManager,
                hasBackgroundMode: true
            )
            deniedKeepAlive.start()
            precondition(!deniedKeepAlive.started)
            precondition(deniedManager.starts == 0)
        }

        let missing = BackgroundLocationKeepAlive(
            manager: manager,
            hasBackgroundMode: false
        )
        missing.start()
        precondition(missing.status == .missingBackgroundMode)
        precondition(!missing.started)

        // Default/off must keep the original indicator and authorization behavior.
        let authorizations: [CLAuthorizationStatus] = [
            .notDetermined, .denied, .restricted, .authorizedWhenInUse, .authorizedAlways
        ]
        for authorization in authorizations {
            let defaultManager = CLLocationManager()
            defaultManager.authorizationStatus = authorization
            let defaultKeepAlive = BackgroundLocationKeepAlive(
                manager: defaultManager, hasBackgroundMode: true
            )
            precondition(!defaultKeepAlive.reducesBackgroundLocationIndicator)
            precondition(defaultManager.showsBackgroundLocationIndicator)
            defaultKeepAlive.start()
            defaultKeepAlive.reconcile()
            defaultKeepAlive.locationManagerDidChangeAuthorization(defaultManager)
            precondition(defaultManager.showsBackgroundLocationIndicator)
            precondition(!defaultKeepAlive.isBackgroundIndicatorHidden)
            precondition(defaultManager.alwaysRequests == 0)
            defaultKeepAlive.stop()
        }

        // Loading a saved preference and session startup never request Always.
        for authorization in authorizations {
            let restoredManager = CLLocationManager()
            restoredManager.authorizationStatus = authorization
            let restored = BackgroundLocationKeepAlive(
                manager: restoredManager, hasBackgroundMode: true,
                reducesBackgroundLocationIndicator: true
            )
            precondition(restoredManager.showsBackgroundLocationIndicator
                == (authorization != .authorizedAlways))
            restored.start()
            restored.reconcile()
            restored.locationManagerDidChangeAuthorization(restoredManager)
            restored.restoreIndicatorPreference(true)
            precondition(restoredManager.alwaysRequests == 0)
            precondition(restoredManager.showsBackgroundLocationIndicator
                == (authorization != .authorizedAlways))
            if authorization == .notDetermined {
                restoredManager.authorizationStatus = .authorizedWhenInUse
                restored.locationManagerDidChangeAuthorization(restoredManager)
                precondition(restoredManager.alwaysRequests == 0)
                precondition(restoredManager.showsBackgroundLocationIndicator)
            }
            restored.stop()
        }

        // Changing an active session's preference takes effect without restarting it.
        let activeManager = CLLocationManager()
        activeManager.authorizationStatus = .authorizedAlways
        let active = BackgroundLocationKeepAlive(manager: activeManager, hasBackgroundMode: true)
        active.start()
        active.setIndicatorPreferenceFromUserAction(true)
        precondition(active.isBackgroundIndicatorHidden && !activeManager.showsBackgroundLocationIndicator)
        active.setIndicatorPreferenceFromUserAction(false)
        precondition(!active.isBackgroundIndicatorHidden && activeManager.showsBackgroundLocationIndicator)
        precondition(activeManager.authorizationStatus == .authorizedAlways) // No permission revocation.
        active.setIndicatorPreferenceFromUserAction(true)
        precondition(!activeManager.showsBackgroundLocationIndicator)
        precondition(active.started && activeManager.starts == 1 && activeManager.stops == 0)
        precondition(activeManager.alwaysRequests == 0) // Already Always: no upgrade needed.

        activeManager.authorizationStatus = .authorizedWhenInUse
        active.locationManagerDidChangeAuthorization(activeManager)
        precondition(active.reducesBackgroundLocationIndicator)
        precondition(activeManager.showsBackgroundLocationIndicator)
        precondition(active.authorizationStatus == .authorizedWhenInUse)
        precondition(activeManager.alwaysRequests == 0) // Downgrade does not trigger an upgrade.
        activeManager.authorizationStatus = .authorizedAlways
        active.reconcile() // Notice a Settings change even without a callback.
        precondition(active.isBackgroundIndicatorHidden)
        activeManager.authorizationStatus = .authorizedWhenInUse
        active.reconcile()
        precondition(activeManager.showsBackgroundLocationIndicator)
        active.setIndicatorPreferenceFromUserAction(false)
        active.setIndicatorPreferenceFromUserAction(true)
        precondition(activeManager.alwaysRequests == 1) // Explicit enabling with While Using.
        precondition(activeManager.showsBackgroundLocationIndicator)
        active.setIndicatorPreferenceFromUserAction(true)
        active.reconcile()
        active.locationManagerDidChangeAuthorization(activeManager) // Upgrade declined/no prompt.
        precondition(activeManager.alwaysRequests == 1)
        precondition(active.reducesBackgroundLocationIndicator && activeManager.showsBackgroundLocationIndicator)
        activeManager.authorizationStatus = .authorizedAlways
        active.locationManagerDidChangeAuthorization(activeManager)
        precondition(active.isBackgroundIndicatorHidden)
        active.stop()
        precondition(!active.started && !activeManager.allowsBackgroundLocationUpdates)
        precondition(activeManager.stops == 1)
        active.reconcile()
        precondition(activeManager.starts == 1 && activeManager.alwaysRequests == 1)

        // Explicit enabling before authorization first requests While Using, then upgrades once.
        let newManager = CLLocationManager()
        let newChoice = BackgroundLocationKeepAlive(manager: newManager, hasBackgroundMode: true)
        newChoice.setIndicatorPreferenceFromUserAction(true)
        precondition(newManager.requests == 1 && newManager.alwaysRequests == 0)
        precondition(newManager.showsBackgroundLocationIndicator)
        newManager.authorizationStatus = .authorizedWhenInUse
        newChoice.locationManagerDidChangeAuthorization(newManager)
        precondition(newManager.alwaysRequests == 1 && newManager.showsBackgroundLocationIndicator)
        newChoice.locationManagerDidChangeAuthorization(newManager)
        newChoice.start()
        newChoice.reconcile()
        precondition(newManager.alwaysRequests == 1)
        newManager.authorizationStatus = .authorizedAlways
        newChoice.locationManagerDidChangeAuthorization(newManager)
        precondition(newChoice.isBackgroundIndicatorHidden)

        // Declining access cancels the pending upgrade; a later Settings grant stays passive.
        let declinedManager = CLLocationManager()
        let declined = BackgroundLocationKeepAlive(manager: declinedManager, hasBackgroundMode: true)
        declined.setIndicatorPreferenceFromUserAction(true)
        declinedManager.authorizationStatus = .denied
        declined.locationManagerDidChangeAuthorization(declinedManager)
        declinedManager.authorizationStatus = .authorizedWhenInUse
        declined.locationManagerDidChangeAuthorization(declinedManager)
        precondition(declined.reducesBackgroundLocationIndicator)
        precondition(declinedManager.alwaysRequests == 0 && declinedManager.showsBackgroundLocationIndicator)

        let cancelledManager = CLLocationManager()
        let cancelled = BackgroundLocationKeepAlive(manager: cancelledManager, hasBackgroundMode: true)
        cancelled.setIndicatorPreferenceFromUserAction(true)
        cancelled.setIndicatorPreferenceFromUserAction(false)
        cancelledManager.authorizationStatus = .authorizedWhenInUse
        cancelled.locationManagerDidChangeAuthorization(cancelledManager)
        precondition(cancelledManager.alwaysRequests == 0 && cancelledManager.showsBackgroundLocationIndicator)

        // With denied/restricted access the toggle retains its choice and requests no permission.
        for authorization: CLAuthorizationStatus in [.denied, .restricted] {
            let blockedManager = CLLocationManager()
            blockedManager.authorizationStatus = authorization
            let blocked = BackgroundLocationKeepAlive(manager: blockedManager, hasBackgroundMode: true)
            blocked.setIndicatorPreferenceFromUserAction(true)
            precondition(blocked.reducesBackgroundLocationIndicator)
            precondition(blockedManager.requests == 0 && blockedManager.alwaysRequests == 0)
            precondition(blockedManager.showsBackgroundLocationIndicator)
        }
        // A native connection may finish after the app went into the background.
        var inForeground = false
        let lateManager = CLLocationManager()
        lateManager.authorizationStatus = .authorizedWhenInUse
        let late = BackgroundLocationKeepAlive(
            manager: lateManager, hasBackgroundMode: true,
            isAppActive: { inForeground }
        )
        late.start()
        precondition(!late.started && lateManager.starts == 0)
        inForeground = true
        late.reconcile()
        precondition(late.started && lateManager.starts == 1)
        inForeground = false
        late.reconcile()
        precondition(late.started && lateManager.starts == 1) // Keep an existing request.
        late.stop()
        inForeground = true
        late.reconcile()
        precondition(!late.started && lateManager.starts == 1) // Never revive a stopped session.

        let pendingManager = CLLocationManager()
        inForeground = false
        let pending = BackgroundLocationKeepAlive(
            manager: pendingManager, hasBackgroundMode: true,
            isAppActive: { inForeground }
        )
        pending.start()
        precondition(pendingManager.requests == 0)
        inForeground = true
        pending.reconcile()
        precondition(pendingManager.requests == 1)
        pending.stop()

        var clock = Date(timeIntervalSinceReferenceDate: 1000)
        let staleManager = CLLocationManager()
        staleManager.authorizationStatus = .authorizedWhenInUse
        let stale = BackgroundLocationKeepAlive(
            manager: staleManager, hasBackgroundMode: true,
            isAppActive: { inForeground }, now: { clock }
        )
        stale.start()
        clock += 61
        inForeground = false
        stale.reconcile()
        precondition(staleManager.starts == 1) // No repeated background restarts.
        inForeground = true
        stale.reconcile()
        precondition(staleManager.starts == 2)
        stale.reconcile()
        precondition(staleManager.starts == 2) // No restart loop while waiting for an update.
        stale.locationManager(staleManager, didUpdateLocations: [CLLocation()])
        precondition(stale.lastUpdateAt == clock && stale.status == .receivingUpdates)
        clock += 59
        stale.reconcile()
        precondition(staleManager.starts == 2)
        clock += 2
        stale.reconcile()
        precondition(staleManager.starts == 3)
        stale.reconcile()
        precondition(staleManager.starts == 3)
        stale.stop()
        clock += 120
        stale.reconcile()
        precondition(staleManager.starts == 3)
        print("Late background startup, foreground reconciliation and stopped-session checks passed")
        print("Background keep-alive lifecycle checks passed")
        print("Indicator preference and explicit authorization upgrade checks passed")
    }
}
'''

with tempfile.TemporaryDirectory() as temporary_directory:
    temporary = Path(temporary_directory)
    source = temporary / "tests.swift"
    binary = temporary / "tests"
    source.write_text(fakes + keep_alive + checks, encoding="utf-8")
    subprocess.run(
        [
            "xcrun", "swiftc", "-parse-as-library",
            "-module-cache-path", str(temporary / "cache"),
            str(source), "-o", str(binary),
        ],
        check=True,
    )
    subprocess.run([str(binary)], check=True)

pairing = PAIRING.read_text(encoding="utf-8")
session = SESSION.read_text(encoding="utf-8")
info = plistlib.loads(INFO.read_bytes())

assert "BGTaskScheduler.shared" not in pairing
assert "runNativePairing()" in method_block(pairing, "    func start(")
assert "beginBackgroundAssertion()" in method_block(pairing, "    func start(")
assert "submitTaskRequest" not in session
assert "BGTaskScheduler.shared" not in session
assert "runNativeLocationSession()" in method_block(session, "    private func submitLocationTask()")
assert "backgroundKeepAlive.start()" in method_block(session, "    fileprivate func nativeLocationStarted()")
startup = method_block(session, "    func start(")
assert startup.index("backgroundKeepAlive.start()") < startup.index("startBuiltInTunnelForPendingSession()")
for marker in [
    "    func stop()",
    "    private func nativeLocationFinished(",
    "    private func fail(",
    "    private func clearPendingSession()",
]:
    assert "backgroundKeepAlive.stop()" in method_block(session, marker)
assert info.get("UIBackgroundModes") == ["location"]
assert "BGTaskSchedulerPermittedIdentifiers" not in info
print("Pairing and location sessions are independent of BGTaskScheduler")
