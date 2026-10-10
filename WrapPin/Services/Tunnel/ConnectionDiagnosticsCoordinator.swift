import Foundation
import Network
import Observation
import WrapPinPairingFFI

enum ConnectionCheckState: Equatable {
    case notRun
    case running
    case passed(String)
    case failed(String)
}

@MainActor
@Observable
final class ConnectionDiagnosticsCoordinator: NSObject {
    private let browser = NetServiceBrowser()
    private var pairingRecord: Data?
    private var discoveredServices: [NetService] = []
    private var timeoutTask: Task<Void, Never>?
    private var sawNonMatchingService = false
    private var sawMatchingUnreachableService = false
    private var serviceProbeConnection: NWConnection?
    private var serviceProbeTimeout: Task<Void, Never>?
    private let serviceProbeQueue = DispatchQueue(
        label: "com.suversal.wrappin.diagnostics-probe",
        qos: .userInitiated
    )

    private(set) var state: ConnectionCheckState = .notRun
    private(set) var lastChecked: Date?

    override init() {
        super.init()
        browser.delegate = self
        browser.includesPeerToPeer = true
    }

    func run(
        pairingRecord: Data?,
        sessionPhase: DeviceSessionPhase,
        tunnelHandoffApp: TunnelHandoffApp
    ) {
        cancel(resetState: false)

        guard let pairingRecord else {
            finish(.failed("This iPhone is not paired. Open Pairing & Connection and pair it first."))
            return
        }

        switch sessionPhase {
        case .active:
            finish(.passed("The secure location session is active and responding."))
            return
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            finish(.failed("WrapPin is already changing the connection. Let it finish, then run the check again."))
            return
        case .idle, .failed:
            break
        }

#if targetEnvironment(simulator)
        finish(.failed("Device tunnel reachability can only be checked on a physical iPhone."))
#else
        self.pairingRecord = pairingRecord
        sawNonMatchingService = false
        sawMatchingUnreachableService = false
        state = .running
        browser.delegate = self
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")

        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.state == .running else { return }

            if self.sawMatchingUnreachableService {
                self.finish(.failed(
                    "The paired iPhone was announced, but its tunnel address was not reachable. Reconnect the selected tunnel and check its device and tunnel IP settings."
                ))
            } else if self.sawNonMatchingService {
                self.finish(.failed(
                    "A device announcement is visible, but it does not match the paired iPhone. Restart the selected tunnel and try again."
                ))
            } else {
                self.finish(.failed(TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: tunnelHandoffApp)
                    ? "This iPhone was not reachable through the device tunnel. If you are using an external tunnel app on mobile data, connect to Wi-Fi and run the check again."
                    : "This iPhone was not reachable through the device tunnel. Check that a compatible tunnel is connected. On mobile data, switch data off briefly and run the check again."
                ))
            }
        }
#endif
    }

    func cancel() {
        cancel(resetState: true)
    }

    private func cancel(resetState: Bool) {
        timeoutTask?.cancel()
        timeoutTask = nil
        serviceProbeTimeout?.cancel()
        serviceProbeTimeout = nil
        serviceProbeConnection?.stateUpdateHandler = nil
        serviceProbeConnection?.cancel()
        serviceProbeConnection = nil
        browser.stop()

        for service in discoveredServices {
            service.stopMonitoring()
            service.stop()
            service.remove(from: .main, forMode: .common)
            service.delegate = nil
        }

        discoveredServices = []
        pairingRecord = nil
        sawNonMatchingService = false
        sawMatchingUnreachableService = false

        if resetState, state == .running {
            state = .notRun
        }
    }

    private func resolve(_ service: NetService) {
        guard state == .running else { return }
        service.delegate = self
        service.includesPeerToPeer = true
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 7)
        discoveredServices.append(service)
    }

    private func inspect(_ service: NetService) {
        guard state == .running, discoveredServices.contains(where: { $0 === service }),
              service.port > 0, service.port <= Int(UInt16.max) else { return }
        service.startMonitoring()

        guard
            let pairingRecord,
            let txtData = service.txtRecordData()
        else { return }

        let values = NetService.dictionary(fromTXTRecord: txtData)
        guard
            let identifierData = values["identifier"],
            let authTagData = values["authTag"]
        else { return }

        let identifier = String(decoding: identifierData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let authTag = String(decoding: authTagData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !authTag.isEmpty else { return }

        let matchesPairedDevice = pairingRecord.withUnsafeBytes { recordBytes in
            guard let recordBaseAddress = recordBytes.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }

            return identifier.withCString { serviceIdentifier in
                authTag.withCString { serviceAuthTag in
                    wp_pairing_record_matches_service(
                        recordBaseAddress,
                        pairingRecord.count,
                        serviceIdentifier,
                        serviceAuthTag
                    ) == 1
                }
            }
        }

        if matchesPairedDevice {
            probe(service)
        } else {
            sawNonMatchingService = true
        }
    }

    private func probe(_ service: NetService) {
        guard serviceProbeConnection == nil else { return }
        guard
            service.port <= Int(UInt16.max),
            let port = NWEndpoint.Port(rawValue: UInt16(service.port))
        else {
            sawMatchingUnreachableService = true
            return
        }

        let endpoint = NetServiceEndpointResolver.preferredHost(
            from: service.addresses,
            fallback: "10.7.0.1"
        )
        probe(
            host: endpoint.host,
            port: port,
            fallbackHost: endpoint.usedFallback || endpoint.host == "10.7.0.1"
                ? nil
                : "10.7.0.1"
        )
    }

    private func probe(
        host: String,
        port: NWEndpoint.Port,
        fallbackHost: String?
    ) {
        guard serviceProbeConnection == nil else { return }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        serviceProbeConnection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] connectionState in
            guard let connection else { return }
            switch connectionState {
            case .ready:
                Task { @MainActor [weak self] in
                    self?.finishProbe(
                        connection,
                        reachable: true,
                        port: port,
                        fallbackHost: fallbackHost
                    )
                }
            case .failed:
                Task { @MainActor [weak self] in
                    self?.finishProbe(
                        connection,
                        reachable: false,
                        port: port,
                        fallbackHost: fallbackHost
                    )
                }
            case .setup, .waiting, .preparing, .cancelled:
                break
            @unknown default:
                break
            }
        }
        serviceProbeTimeout = Task { @MainActor [weak self, weak connection] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, let connection else { return }
            self.finishProbe(
                connection,
                reachable: false,
                port: port,
                fallbackHost: fallbackHost
            )
        }
        connection.start(queue: serviceProbeQueue)
    }

    private func finishProbe(
        _ connection: NWConnection,
        reachable: Bool,
        port: NWEndpoint.Port,
        fallbackHost: String?
    ) {
        guard serviceProbeConnection === connection else { return }
        serviceProbeTimeout?.cancel()
        serviceProbeTimeout = nil
        serviceProbeConnection = nil
        connection.stateUpdateHandler = nil
        connection.cancel()

        if reachable {
            finish(.passed("The pairing record is valid and this iPhone is reachable through the device tunnel."))
        } else if let fallbackHost {
            probe(host: fallbackHost, port: port, fallbackHost: nil)
        } else {
            sawMatchingUnreachableService = true
        }
    }

    private func finish(_ newState: ConnectionCheckState) {
        cancel(resetState: false)
        switch newState {
        case .passed(let message):
            state = .passed(NSLocalizedString(message, comment: ""))
        case .failed(let message):
            state = .failed(NSLocalizedString(message, comment: ""))
        case .notRun, .running:
            state = newState
        }
        lastChecked = Date()
    }
}

extension ConnectionDiagnosticsCoordinator: NetServiceBrowserDelegate, NetServiceDelegate {
    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        MainActor.assumeIsolated {
            resolve(service)
        }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        MainActor.assumeIsolated {
            finish(.failed("Local Network access is unavailable. Allow it in iPhone Settings, then try again."))
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        MainActor.assumeIsolated {
            inspect(sender)
        }
    }

    nonisolated func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        MainActor.assumeIsolated {
            inspect(sender)
        }
    }
}
