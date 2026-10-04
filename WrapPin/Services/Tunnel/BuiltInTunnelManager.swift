import Foundation
import NetworkExtension
import Combine

@MainActor
final class BuiltInTunnelManager: ObservableObject {
    static let shared = BuiltInTunnelManager()
    static let defaultLocalAddress = "10.7.0.2/30"
    static let peerAddress = "10.7.0.1/32"
    private static let localAddressKey = "builtInTunnelLocalAddress"
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var lastError: String?
    @Published private(set) var lastErrorDetail: String?
    @Published private(set) var localAddress: String
    @Published private(set) var hasConfiguration = false
    @Published private(set) var isConfigurationEnabled = false
    @Published private(set) var isStarting = false
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var keepRunningAfterSession = false
    private var startedForSession = false
    private var currentStartID: UUID?

    init() {
        localAddress = Self.normalizedLocalAddress(UserDefaults.standard.string(forKey: Self.localAddressKey) ?? "")
            ?? Self.defaultLocalAddress
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let connection = notification.object as? NEVPNConnection else { return }
            Task { @MainActor in
                if connection === self.manager?.connection {
                    self.status = connection.status
                    if self.isStarting && connection.status == .disconnected {
                        connection.fetchLastDisconnectError { error in
                            guard let error else { return }
                            Task { @MainActor in self.report(error, stage: "connect") }
                        }
                    }
                }
            }
        }
    }

    deinit {
        if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
    }

    func refresh() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            let matching = managers.filter {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID
            }
            manager = matching.first(where: \.isEnabled) ?? matching.first
            hasConfiguration = manager != nil
            isConfigurationEnabled = manager?.isEnabled ?? false
            status = manager?.connection.status ?? .invalid
        } catch {
            report(error, stage: "load")
        }
    }

    @discardableResult
    func setLocalAddress(_ value: String) -> Bool {
        guard let normalized = Self.normalizedLocalAddress(value) else { return false }
        localAddress = normalized
        UserDefaults.standard.set(normalized, forKey: Self.localAddressKey)
        return true
    }

    static func normalizedLocalAddress(_ value: String) -> String? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let prefix = Int(parts[1]), (1...32).contains(prefix) else { return nil }
        let octets = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        let numbers = octets.compactMap { Int($0) }
        guard numbers.count == 4, numbers.allSatisfy({ (0...255).contains($0) }),
              (1...223).contains(numbers[0]), numbers[0] != 127,
              numbers != [10, 7, 0, 1] else { return nil }
        let address = numbers.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let mask = UInt32.max << (32 - prefix)
        if prefix < 31 && (address & ~mask == 0 || address & ~mask == ~mask) { return nil }
        return numbers.map(String.init).joined(separator: ".") + "/\(prefix)"
    }

    func start() async {
        if await startForSession() {
            keepRunningAfterSession = true
            startedForSession = false
        }
    }

    func startForSession() async -> Bool {
        guard !isStarting else { return false }
        isStarting = true
        defer { isStarting = false }
        let startID = UUID()
        currentStartID = startID
        lastError = nil
        lastErrorDetail = nil
        await refresh()
        guard !Task.isCancelled, currentStartID == startID else { return false }
        guard lastError == nil else { return false }
        if status == .connected { return true }
        startedForSession = true
        await startTunnel(startID: startID)
        guard currentStartID == startID else { return false }
        guard lastError == nil else { startedForSession = false; return false }
        for _ in 0..<40 {
            guard currentStartID == startID else { return false }
            guard lastError == nil else { stopAfterSession(); return false }
            if Task.isCancelled {
                stopAfterSession()
                return false
            }
            if manager?.connection.status == .connected {
                status = .connected
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        stopAfterSession()
        lastError = String(localized: "Built-in tunnel did not connect in time. Check the VPN configuration and signing permissions, then try again.")
        lastErrorDetail = "connect: timeout after 10 seconds"
        return false
    }

    private func startTunnel(startID: UUID) async {
        do {
            let tunnel = manager ?? NETunnelProviderManager()
            let savedConfiguration = tunnel.protocolConfiguration as? NETunnelProviderProtocol
            let savedAddress = savedConfiguration?.providerConfiguration?["localAddress"] as? String
            let needsSave = manager == nil || !tunnel.isEnabled
                || savedConfiguration?.providerBundleIdentifier != providerBundleID
                || savedAddress != localAddress
            // iOS can disable an existing configuration after re-signing or a user change.
            // An explicit start is permission to enable and persist it again.
            if needsSave {
                let configuration = NETunnelProviderProtocol()
                configuration.providerBundleIdentifier = providerBundleID
                configuration.serverAddress = "WrapPin local device"
                configuration.providerConfiguration = ["localAddress": localAddress]
                tunnel.protocolConfiguration = configuration
                tunnel.localizedDescription = "WrapPin Device Tunnel"
                tunnel.isEnabled = true
                try await tunnel.saveToPreferences()
                try await tunnel.loadFromPreferences()
            }
            manager = tunnel
            hasConfiguration = true
            isConfigurationEnabled = tunnel.isEnabled
            guard tunnel.isEnabled else {
                throw NSError(domain: NEVPNErrorDomain, code: 2)
            }
            guard !Task.isCancelled, currentStartID == startID else { return }
            try tunnel.connection.startVPNTunnel()
            status = tunnel.connection.status
            lastError = nil
            lastErrorDetail = nil
        } catch {
            report(error, stage: "start")
        }
    }

    func stop() {
        currentStartID = nil
        keepRunningAfterSession = false
        startedForSession = false
        manager?.connection.stopVPNTunnel()
        status = manager?.connection.status ?? .invalid
    }

    func stopAfterSession() {
        guard startedForSession, !keepRunningAfterSession else { return }
        currentStartID = nil
        startedForSession = false
        manager?.connection.stopVPNTunnel()
        status = manager?.connection.status ?? .invalid
    }

    private var providerBundleID: String {
        (Bundle.main.bundleIdentifier ?? "com.suversal.wrappin") + ".tunnel"
    }

    private func report(_ error: Error, stage: String) {
        let actual = error as NSError
        lastErrorDetail = "\(stage): \(actual.domain) \(actual.code) — \(actual.localizedDescription)"
        if actual.domain == NEVPNErrorDomain && actual.code == 2 {
            lastError = String(localized: "iOS still keeps this VPN configuration disabled. Open Settings > General > VPN & Device Management > VPN, enable WrapPin, then try again. If it cannot be enabled, check both signing profiles.")
        } else if actual.domain == NEVPNErrorDomain && actual.code == 4 {
            lastError = String(localized: "The VPN configuration changed. Close this page and try again.")
        } else if actual.domain == NEVPNErrorDomain && actual.code == 5 {
            lastError = String(localized: "iOS could not read or save the VPN configuration. Check VPN approval and the app and extension signing profiles, then try again.")
        } else {
            lastError = String(format: String(localized: "Could not start the built-in tunnel (%@). Check VPN approval and signing permissions, then try again."), actual.localizedDescription)
        }
    }
}
