import Foundation
import NetworkExtension
import Combine

@MainActor
final class BuiltInTunnelManager: ObservableObject {
    static let shared = BuiltInTunnelManager()
    @Published private(set) var status: NEVPNStatus = .invalid
    @Published private(set) var lastError: String?
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var keepRunningAfterSession = false
    private var startedForSession = false
    private var currentStartID: UUID?

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let connection = notification.object as? NEVPNConnection else { return }
            Task { @MainActor in
                if connection === self.manager?.connection {
                    self.status = connection.status
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
            manager = managers.first {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID
            }
            status = manager?.connection.status ?? .invalid
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func start() async {
        if await startForSession() {
            keepRunningAfterSession = true
            startedForSession = false
        }
    }

    func startForSession() async -> Bool {
        let startID = UUID()
        currentStartID = startID
        await refresh()
        guard !Task.isCancelled, currentStartID == startID else { return false }
        if status == .connected { return true }
        startedForSession = true
        await startTunnel(startID: startID)
        guard currentStartID == startID else { return false }
        guard lastError == nil else { startedForSession = false; return false }
        for _ in 0..<40 {
            guard currentStartID == startID else { return false }
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
        lastError = String(localized: "Built-in tunnel did not connect in time.")
        return false
    }

    private func startTunnel(startID: UUID) async {
        do {
            if manager == nil {
                let tunnel = NETunnelProviderManager()
                let configuration = NETunnelProviderProtocol()
                configuration.providerBundleIdentifier = providerBundleID
                configuration.serverAddress = "WrapPin local device"
                tunnel.protocolConfiguration = configuration
                tunnel.localizedDescription = "WrapPin Device Tunnel"
                tunnel.isEnabled = true
                try await tunnel.saveToPreferences()
                try await tunnel.loadFromPreferences()
                manager = tunnel
            }
            guard !Task.isCancelled, currentStartID == startID else { return }
            try manager?.connection.startVPNTunnel()
            status = manager?.connection.status ?? .invalid
            lastError = nil
        } catch {
            lastError = error.localizedDescription
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
}
