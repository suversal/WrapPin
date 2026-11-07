import Foundation

enum DevicePairingSupport {
    static var supportsOnDevicePairing: Bool {
#if DEBUG
        // Preview the iOS 26 setup UI on a newer simulator; no device handshake is simulated.
        if ProcessInfo.processInfo.arguments.contains("--preview-computer-pairing") { return false }
#endif
        return supportsOnDevicePairing(on: ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func supportsOnDevicePairing(on version: OperatingSystemVersion) -> Bool {
        version.majorVersion >= 27
    }
}
