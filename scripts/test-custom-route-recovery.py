#!/usr/bin/env python3
"""Exercise production recovery persistence, including closed custom loops."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'WrapPin/App/AppModel.swift').read_text()

def method(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 0
    for end in range(opening, len(source)):
        depth += (source[end] == '{') - (source[end] == '}')
        if depth == 0:
            return source[start:end + 1].replace('private func', 'func')
    raise AssertionError(marker)

fakes = r'''
import Foundation
import CoreLocation
enum RouteMode: String, Codable { case walking, driving }
@MainActor final class Model {
    static let activeSessionRecoveryKey = "custom-route-test"
    let preferences: UserDefaults
    var activeSessionRecovery: SessionRecoveryRecord?
    var lastRecoverySaveDate: Date?
    init(_ preferences: UserDefaults) { self.preferences = preferences }
'''
checks = r'''
}
@main struct Checks {
    @MainActor static func main() throws {
        let suite = "wrappin-custom-recovery-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let model = Model(preferences)
        let end = LocationTarget(name: "Loop", subtitle: "", latitude: 24.7, longitude: 46.7)
        let middle = LocationTarget(name: "Midpoint", subtitle: "", latitude: 24.8, longitude: 46.8)
        var loop = SessionRecoveryRecord.route(from: end, to: end, mode: .walking,
            coordinateMode: .wgs84, speedMetresPerSecond: 5 / 3.6)
        loop.customRoutePoints = [SavedRoutePoint(latitude: end.latitude, longitude: end.longitude),
                                  SavedRoutePoint(latitude: middle.latitude, longitude: middle.longitude),
                                  SavedRoutePoint(latitude: end.latitude, longitude: end.longitude)]
        loop.nextCustomRoutePointIndex = 1
        model.activeSessionRecovery = loop
        model.persistActiveSessionRecovery(at: end)
        precondition(model.activeSessionRecovery?.isRoute == true, "Loop start must not count as arrival")
        model.lastRecoverySaveDate = .distantPast
        model.recordCustomRouteProgress(nextPointIndex: 2, at: middle)
        let data = preferences.data(forKey: Model.activeSessionRecoveryKey)!
        let saved = try JSONDecoder().decode(SessionRecoveryRecord.self, from: data)
        precondition(saved.lastReportedLocation == middle && saved.nextCustomRoutePointIndex == 2)
        precondition(saved.customRoutePoints == loop.customRoutePoints)
        model.persistActiveSessionRecovery(at: end)
        precondition(model.activeSessionRecovery?.isRoute == true, "Endpoint encountered early must preserve geometry")
        model.recordCustomRouteProgress(nextPointIndex: 3, at: end)
        precondition(model.activeSessionRecovery?.kind == .fixedLocation)
        precondition(model.activeSessionRecovery?.customRoutePoints == nil)
        let arrived = try JSONDecoder().decode(SessionRecoveryRecord.self,
            from: preferences.data(forKey: Model.activeSessionRecoveryKey)!)
        precondition(arrived.kind == .fixedLocation && arrived.lastReportedLocation == end)
        print("Custom recovery persistence: closed loops, next waypoint, saved coordinates and final arrival passed")
    }
}
'''
production = '\n'.join((root / path).read_text() for path in [
    'WrapPin/Models/LocationTarget.swift',
    'WrapPin/Services/FixedCoordinateMode.swift',
    'WrapPin/Models/SessionRecoveryRecord.swift',
])
with tempfile.TemporaryDirectory(prefix='wrappin-custom-recovery-') as directory:
    directory = Path(directory)
    swift = directory / 'Checks.swift'
    binary = directory / 'checks'
    swift.write_text(production + fakes + method('    func recordCustomRouteProgress(')
                     + '\n' + method('    private func persistActiveSessionRecovery(') + checks)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', str(directory / 'cache'),
                    str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=30)
