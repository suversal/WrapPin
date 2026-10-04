import Foundation
import Network
import Observation
import WrapPinPairingFFI
import UIKit

enum DeviceSessionPhase: Equatable {
    case idle
    case openingLocalDevVPN
    case discovering
    case connecting
    case active(LocationTarget)
    case stopping
    case failed(String)
}

enum MobileDataGuidance: Equatable {
    case connectionHelp
    case turnOff
    case turnBackOn
}

enum ActiveLocationUpdateResult: Equatable {
    case unavailable
    case updated
    case failed
}

enum DeviceSessionConnectionStage: Equatable, Sendable {
    case idle
    case choosingNetwork
    case openingLocalDevVPN
    case discoveringDevice
    case verifyingDevice
    case waitingForSystem
    case openingSecureSession
    case active
    case restoringRealLocation
    case failed

    var title: String {
        switch self {
        case .idle: String(localized: "Idle")
        case .choosingNetwork: String(localized: "Checking network")
        case .openingLocalDevVPN: String(localized: "Opening tunnel app")
        case .discoveringDevice: String(localized: "Discovering this iPhone")
        case .verifyingDevice: String(localized: "Verifying paired device")
        case .waitingForSystem: String(localized: "Waiting for system resources")
        case .openingSecureSession: String(localized: "Opening secure session")
        case .active: String(localized: "Location session active")
        case .restoringRealLocation: String(localized: "Restoring real location")
        case .failed: String(localized: "Connection failed")
        }
    }
}

enum DeviceEndpointSource: Equatable, Sendable {
    case discovered
    case fallback

    var title: String {
        switch self {
        case .discovered: String(localized: "Discovered automatically")
        case .fallback: String(localized: "Default address fallback")
        }
    }
}

@MainActor
@Observable
final class LocalDeviceSessionCoordinator: NSObject {
    private struct PendingSession {
        let pairingRecord: Data
        let target: LocationTarget
        let simulationCoordinates: SimulationCoordinates
    }

    private struct RemotePairingService: Sendable {
        let host: String
        let port: UInt16
        let identifier: String
        let authTag: String
        let endpointSource: DeviceEndpointSource
        let fallbackHost: String?
    }

    private static let localDevVPNPeerAddress = "10.7.0.1"
    private static let minimumRestorationDisplayDuration: TimeInterval = 1.2

    private(set) var phase: DeviceSessionPhase = .idle {
        didSet {
            guard phase != oldValue else { return }
            if phase == .idle {
                BuiltInTunnelManager.shared.stopAfterSession()
            }
            if case .failed(let message) = phase {
                guard !terminalFailureReported else { return }
                terminalFailureReported = true
                let stage = FailureStage.classify(message, fallback: .locationUnknown)
                lastFailureStage = stage
                lastFailureDisposition = .terminal
                onFailure?(stage)
            }
            onPhaseChange?(phase)
        }
    }
    private(set) var mobileDataGuidance: MobileDataGuidance? {
        didSet {
            if mobileDataGuidance == .connectionHelp, oldValue != .connectionHelp {
                onConnectionEvent?(.connectionHelpShown)
            }
        }
    }
    let backgroundKeepAlive = BackgroundLocationKeepAlive()
    var tunnelHandoffApp: TunnelHandoffApp = .localDevVPN {
        didSet {
            if tunnelHandoffApp != oldValue {
                hasReachedDeviceTunnel = false
            }
        }
    }
    var usesBuiltInTunnel = false
    private var builtInTunnelStartupTask: Task<Void, Never>?
    private var builtInTunnelStartupID: UUID?
    var isUsingMobileDataForStartup: Bool { isMobileDataStartupMode }
    private(set) var connectionStage: DeviceSessionConnectionStage = .idle
    private(set) var endpointSource: DeviceEndpointSource?
    private(set) var lastFailureMessage: String?
    var onConnectionEvent: ((UsageAnalyticsEvent) -> Void)?
    private var retryTelemetry = ConnectionRetryTelemetry()
    private var vpnReturnRetryUsed = false
    private var vpnReturnRetryTask: Task<Void, Never>?

    private(set) var restorationStatus = String(localized: "Not requested")
    private(set) var schedulerFailureReason: SchedulerFailureReason?
    private(set) var lastFailureStage: FailureStage?
    private(set) var lastFailureDisposition: FailureDisposition?
    var onRecoveryNeeded: ((FailureStage) -> Void)?
    private var terminalFailureReported = false
    var onFailure: ((FailureStage) -> Void)?

    var onPhaseChange: ((DeviceSessionPhase) -> Void)?

    var activeSimulationCoordinates: SimulationCoordinates? {
        guard case .active = phase else { return nil }
        return pendingSession?.simulationCoordinates
    }

    private let browser = NetServiceBrowser()
    private let wifiPathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let wifiPathMonitorQueue = DispatchQueue(
        label: "com.suversal.wrappin.wifi-path",
        qos: .utility
    )
    private let serviceProbeQueue = DispatchQueue(
        label: "com.suversal.wrappin.service-probe",
        qos: .userInitiated
    )
    private var discoveredServices: [NetService] = []
    private var discoveryTimeout: Task<Void, Never>?
    private var automaticDiscoveryTask: Task<Void, Never>?
    private var networkDecisionTask: Task<Void, Never>?
    private var mobileDataDiscoveryLoopTask: Task<Void, Never>?
    private var mobileDataGuidanceDelay: Task<Void, Never>?
    private var tunnelAppProbeTask: Task<Void, Never>?
    private var localDevVPNReturnTimeout: Task<Void, Never>?
    private var pendingSession: PendingSession?
    private var resolvedService: RemotePairingService?
    private var sawNonMatchingService = false
    private var isDiscoveringServices = false
    private var hasOpenedTunnelAppThisAttempt = false
    private var hasReachedDeviceTunnel = false
    private var wifiPathStatusIsKnown = false
    private var isWiFiPathSatisfied = false
    private var isMobileDataStartupMode = false
    private var serviceProbeConnection: NWConnection?
    private var serviceProbeTimeout: Task<Void, Never>?
    private var serviceProbeRetryTask: Task<Void, Never>?
    private var serviceProbeAttemptCount = 0

    private var activeSession: OpaquePointer?
    private var activeRunIdentifier: UUID?
    private var workerIsRunning = false
    private var cancellationRequested = false
    private var pendingFailureMessage: String?
    private var restorationDisplayStartDate: Date?

    override init() {
        super.init()
        browser.delegate = self
        browser.includesPeerToPeer = true
        wifiPathMonitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.wifiPathStatusIsKnown = true
                self?.isWiFiPathSatisfied = isSatisfied
            }
        }
        wifiPathMonitor.start(queue: wifiPathMonitorQueue)
    }

    var isBusy: Bool {
        switch phase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    func start(
        pairingRecord: Data,
        target: LocationTarget,
        simulationCoordinates: SimulationCoordinates? = nil
    ) {
        guard !workerIsRunning, !isBusy else { return }
        terminalFailureReported = false
        retryTelemetry.reset()
        schedulerFailureReason = nil
        lastFailureStage = nil
        lastFailureDisposition = nil
        restorationStatus = String(localized: "Not requested")
        vpnReturnRetryUsed = false

#if targetEnvironment(simulator)
        connectionStage = .failed
        let message = NSLocalizedString(
            "A real iPhone is required to start a location session.",
            comment: ""
        )
        lastFailureMessage = message
        phase = .failed(message)
#else
        cancellationRequested = false
        pendingFailureMessage = nil
        lastFailureMessage = nil
        endpointSource = nil
        connectionStage = .choosingNetwork
        restorationDisplayStartDate = nil
        mobileDataGuidance = nil
        hasOpenedTunnelAppThisAttempt = false
        // Reachability from a previous location session says nothing about the tunnel now.
        hasReachedDeviceTunnel = false
        isMobileDataStartupMode = false
        pendingSession = PendingSession(
            pairingRecord: pairingRecord,
            target: target,
            simulationCoordinates: simulationCoordinates ?? SimulationCoordinates(target)
        )
        resolvedService = nil
        phase = .discovering
        if usesBuiltInTunnel {
            startBuiltInTunnelForPendingSession()
        } else {
            routeStartupForCurrentNetwork()
        }
#endif
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme?.lowercased() == BuildEdition.callbackScheme else { return }
        guard pendingSession != nil else { return }
        guard phase == .openingLocalDevVPN || phase == .discovering else { return }

        localDevVPNReturnTimeout?.cancel()
        localDevVPNReturnTimeout = nil
        guard mobileDataGuidance != .turnOff else { return }
        resumeAfterTunnelApp()
    }

    @discardableResult
    func updateLocation(
        _ target: LocationTarget,
        simulationCoordinates: SimulationCoordinates? = nil
    ) -> ActiveLocationUpdateResult {
        guard
            workerIsRunning,
            case .active = phase,
            let activeSession,
            let pendingSession
        else { return .unavailable }

        let coordinates = simulationCoordinates ?? SimulationCoordinates(target)
        guard wp_location_session_update(activeSession, coordinates.latitude, coordinates.longitude) == 0 else {
            fail("WrapPin could not update the active location.")
            return .failed
        }

        self.pendingSession = PendingSession(
            pairingRecord: pendingSession.pairingRecord,
            target: target,
            simulationCoordinates: coordinates
        )
        phase = .active(target)
        connectionStage = .active
        return .updated
    }

    func openSelectedTunnelApp() {
#if !targetEnvironment(simulator)
        if usesBuiltInTunnel {
            startBuiltInTunnelForPendingSession()
            return
        }
        if pendingSession != nil, !workerIsRunning {
            openSelectedTunnelAppForPendingSession()
            return
        }

        UIApplication.shared.open(tunnelHandoffApp.launchURL) { [weak self] opened in
            guard !opened else { return }
            Task { @MainActor in
                self?.fail("Could not open the selected tunnel app. Check that it is installed and supports app links.")
            }
        }
#endif
    }

    func dismissMobileDataGuidance() {
        mobileDataGuidance = nil
    }

    func confirmMobileDataIsOff() {
        guard mobileDataGuidance == .turnOff, pendingSession != nil else { return }
        automaticDiscoveryTask?.cancel()
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        automaticDiscoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled, let self else { return }
            self.automaticDiscoveryTask = nil
            self.startMobileDataDiscoveryLoop()
        }
    }

    func useMobileDataGuidance() {
        guard mobileDataGuidance == .connectionHelp, pendingSession != nil else { return }
        guard TunnelHandoffPolicy.offersMobileDataWorkaround(for: tunnelHandoffApp) else { return }
        isMobileDataStartupMode = true
        enterMobileDataGuidance()
    }

    func retryConnection() {
        guard mobileDataGuidance == .connectionHelp, pendingSession != nil else { return }
        onConnectionEvent?(retryTelemetry.selected())
        if tunnelHandoffApp == .shadowrocket {
            isMobileDataStartupMode = wifiPathStatusIsKnown && !isWiFiPathSatisfied
        }
        mobileDataGuidance = nil
        resolvedService = nil
        beginDiscovery(showConnectionHelpIfUnavailable: true)
    }

    func appDidBecomeActive() {
        if
            phase == .openingLocalDevVPN,
            pendingSession != nil,
            !workerIsRunning
        {
            automaticDiscoveryTask?.cancel()
            automaticDiscoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard
                    !Task.isCancelled,
                    let self,
                    self.pendingSession != nil,
                    self.phase == .openingLocalDevVPN,
                    !self.workerIsRunning
                else { return }

                self.automaticDiscoveryTask = nil
                self.resumeAfterTunnelApp()
            }
            return
        }

        guard mobileDataGuidance == .turnOff else { return }
        startMobileDataDiscoveryLoop()
    }

    func stop() {
        backgroundKeepAlive.stop()
        mobileDataGuidance = nil
        switch phase {
        case .idle:
            return
        case .openingLocalDevVPN, .discovering:
            cancellationRequested = true
            cleanupDiscovery()
            clearPendingSession()
            phase = .idle
        case .connecting:
            cancellationRequested = true
            phase = .stopping
            connectionStage = .restoringRealLocation
            if let activeSession {
                wp_location_session_cancel(activeSession)
            } else {
                clearPendingSession()
                phase = .idle
                connectionStage = .idle
            }
        case .active:
            cancellationRequested = true
            restorationStatus = String(localized: "Stop requested; awaiting device response")
            restorationDisplayStartDate = .now
            phase = .stopping
            if let activeSession {
                wp_location_session_cancel(activeSession)
            }
        case .stopping:
            break
        case .failed:
            clearPendingSession()
            phase = .idle
            connectionStage = .idle
        }
    }

    func reset() {
        stop()
        if !workerIsRunning {
            clearPendingSession()
            phase = .idle
        }
    }

    // A cold VPN start can briefly expose services before the return to the app settles.
    // Retry once per start; never turn this into an unbounded recovery loop.
    private func showConnectionHelp() {
        guard pendingSession != nil, !workerIsRunning else { return }
        guard hasOpenedTunnelAppThisAttempt, !isMobileDataStartupMode,
              !vpnReturnRetryUsed else {
            mobileDataGuidance = .connectionHelp
            return
        }
        vpnReturnRetryUsed = true
        cleanupDiscovery()
        phase = .discovering
        mobileDataGuidance = nil
        vpnReturnRetryTask = Task { @MainActor [weak self] in
            // Bound the foreground wait as well as the retry count.
            for _ in 0..<10 {
                do { try await Task.sleep(for: .milliseconds(300)) }
                catch { return }
                guard let self, self.pendingSession != nil,
                      self.phase == .discovering, !self.workerIsRunning else { return }
                if UIApplication.shared.applicationState == .active {
                    self.vpnReturnRetryTask = nil
                    self.resolvedService = nil
                    self.beginDiscovery(showConnectionHelpIfUnavailable: true)
                    return
                }
            }
            guard let self, self.pendingSession != nil, self.phase == .discovering else { return }
            self.vpnReturnRetryTask = nil
            self.mobileDataGuidance = .connectionHelp
        }
    }

    private func beginDiscovery(
        reportTimeout: Bool = true,
        openTunnelAppIfUnavailable: Bool = false,
        showConnectionHelpIfUnavailable: Bool = false
    ) {
        cleanupDiscovery()
        sawNonMatchingService = false
        isDiscoveringServices = true
        phase = .discovering
        connectionStage = .discoveringDevice
        browser.delegate = self
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")

        if showConnectionHelpIfUnavailable {
            mobileDataGuidanceDelay = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard
                    !Task.isCancelled,
                    let self,
                    self.pendingSession != nil,
                    self.phase == .discovering,
                    !self.workerIsRunning,
                    self.resolvedService == nil
                else { return }
                self.showConnectionHelp()
            }
        }

        if openTunnelAppIfUnavailable {
            tunnelAppProbeTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard
                    !Task.isCancelled,
                    let self,
                    self.pendingSession != nil,
                    self.phase == .discovering,
                    !self.workerIsRunning,
                    self.resolvedService == nil,
                    self.serviceProbeConnection == nil,
                    !self.hasReachedDeviceTunnel
                else { return }

                self.tunnelAppProbeTask = nil
                self.openSelectedTunnelAppForPendingSession()
            }
        }

        if reportTimeout {
            discoveryTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, self.phase == .discovering else { return }
                if !self.hasOpenedTunnelAppThisAttempt && !self.hasReachedDeviceTunnel {
                    self.openSelectedTunnelAppForPendingSession()
                } else if self.sawNonMatchingService {
                    self.fail(
                        "WrapPin found an outdated device announcement. Restart the selected tunnel and try again."
                    )
                } else {
                    self.fail(
                        "WrapPin could not find this iPhone through the device tunnel. Check the selected tunnel and try again."
                    )
                }
            }
        }
    }

    private func resolve(_ service: NetService) {
        service.delegate = self
        service.includesPeerToPeer = true
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 8)
        discoveredServices.append(service)
    }

    private func useResolvedService(_ service: NetService) {
        guard phase == .discovering else { return }
        guard service.port > 0, service.port <= Int(UInt16.max) else { return }
        guard
            let txtData = service.txtRecordData(),
            let identifierData = NetService.dictionary(fromTXTRecord: txtData)["identifier"],
            let authTagData = NetService.dictionary(fromTXTRecord: txtData)["authTag"]
        else { return }

        let identifier = String(decoding: identifierData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let authTag = String(decoding: authTagData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !authTag.isEmpty else { return }
        guard let pairingRecord = pendingSession?.pairingRecord else { return }

        let matchesPairedDevice = pairingRecord.withUnsafeBytes { recordBytes in
            guard let recordBaseAddress = recordBytes.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }

            return identifier.withCString { serviceIdentifier in
                authTag.withCString { authTag in
                    wp_pairing_record_matches_service(
                        recordBaseAddress,
                        pairingRecord.count,
                        serviceIdentifier,
                        authTag
                    ) == 1
                }
            }
        }

        guard matchesPairedDevice else {
            sawNonMatchingService = true
            service.startMonitoring()
            return
        }

        guard serviceProbeConnection == nil, serviceProbeRetryTask == nil else { return }
        let endpoint = NetServiceEndpointResolver.preferredHost(
            from: service.addresses,
            fallback: Self.localDevVPNPeerAddress
        )
        connectionStage = .verifyingDevice
        verifyServiceIsReachable(RemotePairingService(
            host: endpoint.host,
            port: UInt16(service.port),
            identifier: identifier,
            authTag: authTag,
            endpointSource: endpoint.usedFallback ? .fallback : .discovered,
            fallbackHost: endpoint.usedFallback ? nil : Self.localDevVPNPeerAddress
        ))
    }

    private func submitLocationTask() {
        guard pendingSession != nil, resolvedService != nil else {
            fail("WrapPin could not prepare the selected location.")
            return
        }

        phase = .connecting
        connectionStage = .openingSecureSession
        runNativeLocationSession()
    }

    private func runNativeLocationSession() {
        guard let pendingSession, let resolvedService else {
            fail("WrapPin lost the location session details.")
            return
        }
        guard let session = wp_location_session_create() else {
            fail("WrapPin could not start its location engine.")
            return
        }

        let runIdentifier = UUID()
        activeRunIdentifier = runIdentifier
        activeSession = session
        workerIsRunning = true

        let sessionBits = UInt(bitPattern: session)
        let contextBits = UInt(bitPattern: Unmanaged.passRetained(self).toOpaque())
        let pairingRecord = pendingSession.pairingRecord
        let simulationCoordinates = pendingSession.simulationCoordinates
        let peerAddressString = resolvedService.host

        DispatchQueue.global(qos: .userInitiated).async {
            guard
                let session = OpaquePointer(bitPattern: sessionBits),
                let context = UnsafeMutableRawPointer(bitPattern: contextBits)
            else { return }

            var result = WPLocationResult()
            let returnCode = pairingRecord.withUnsafeBytes { recordBytes in
                guard let recordBaseAddress = recordBytes.bindMemory(to: UInt8.self).baseAddress else {
                    return Int32(-1)
                }

                return peerAddressString.withCString { peerAddress in
                    resolvedService.identifier.withCString { serviceIdentifier in
                        resolvedService.authTag.withCString { authTag in
                            wp_location_session_run(
                                session,
                                recordBaseAddress,
                                pairingRecord.count,
                                peerAddress,
                                resolvedService.port,
                                serviceIdentifier,
                                authTag,
                                simulationCoordinates.latitude,
                                simulationCoordinates.longitude,
                                locationStartedCallback,
                                context,
                                &result
                            )
                        }
                    }
                }
            }

            let outcome = NativeLocationOutcome(result: result, returnCode: returnCode)
            wp_location_result_destroy(&result)

            DispatchQueue.main.async {
                if let session = OpaquePointer(bitPattern: sessionBits) {
                    wp_location_session_destroy(session)
                }
                let coordinator = Unmanaged<LocalDeviceSessionCoordinator>
                    .fromOpaque(context)
                    .takeRetainedValue()
                coordinator.nativeLocationFinished(outcome, runIdentifier: runIdentifier)
            }
        }
    }

    fileprivate func nativeLocationStarted() {
        guard workerIsRunning, !cancellationRequested, let target = pendingSession?.target else { return }
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        backgroundKeepAlive.start()
        phase = .active(target)
        connectionStage = .active
        if let event = retryTelemetry.becameActive() {
            onConnectionEvent?(event)
        }
        if mobileDataGuidance == .turnOff {
            mobileDataGuidance = .turnBackOn
        }
    }

    private func nativeLocationFinished(
        _ outcome: NativeLocationOutcome,
        runIdentifier: UUID
    ) {
        guard activeRunIdentifier == runIdentifier else { return }

        activeRunIdentifier = nil
        activeSession = nil
        workerIsRunning = false
        backgroundKeepAlive.stop()

        if let pendingFailureMessage {
            self.pendingFailureMessage = nil
            mobileDataGuidance = nil
            clearPendingSession()
            phase = .failed(pendingFailureMessage)
            connectionStage = .failed
            lastFailureMessage = pendingFailureMessage
            return
        }

        if cancellationRequested {
            cancellationRequested = false
            if case .failure(let message) = outcome,
               message != "The location session was stopped." {
                restorationStatus = String(localized: "Stop not confirmed; real location unverified")
                clearPendingSession()
                phase = .failed(message)
                return
            }
            if restorationDisplayStartDate != nil {
                restorationStatus = String(localized: "Stop command acknowledged; real location reacquisition unverified")
            }
            clearPendingSession()
            finishCancelledLocationSession()
            return
        }

        switch outcome {
        case .success:
            mobileDataGuidance = nil
            clearPendingSession()
            phase = .idle
            connectionStage = .idle
        case .failure(let message):
            if isRecoverableTunnelConnectionFailure(message) {
                let stage = FailureStage.classify(message, fallback: .locationUnknown)
                lastFailureStage = stage
                lastFailureDisposition = .recoverable
                onRecoveryNeeded?(stage)
                resolvedService = nil
                if isMobileDataStartupMode &&
                    TunnelHandoffPolicy.offersMobileDataWorkaround(for: tunnelHandoffApp) {
                    enterMobileDataGuidance()
                } else if !hasOpenedTunnelAppThisAttempt && !hasReachedDeviceTunnel {
                    openSelectedTunnelAppForPendingSession()
                } else {
                    phase = .discovering
                    showConnectionHelp()
                }
                return
            }

            let localizedMessage = NSLocalizedString(message, comment: "")
            mobileDataGuidance = nil
            clearPendingSession()
            phase = .failed(localizedMessage)
            connectionStage = .failed
            lastFailureMessage = localizedMessage
        }
    }

    private func fail(_ message: String) {
        backgroundKeepAlive.stop()
        let localizedMessage = NSLocalizedString(message, comment: "")
        lastFailureMessage = localizedMessage
        connectionStage = .failed
        localDevVPNReturnTimeout?.cancel()
        localDevVPNReturnTimeout = nil
        mobileDataGuidance = nil
        cleanupDiscovery()

        if workerIsRunning, let activeSession {
            pendingFailureMessage = localizedMessage
            wp_location_session_cancel(activeSession)
        } else {
            clearPendingSession()
        }

        phase = .failed(localizedMessage)
    }

    private func cleanupDiscovery() {
        vpnReturnRetryTask?.cancel()
        vpnReturnRetryTask = nil
        isDiscoveringServices = false
        cleanupServiceProbe()
        discoveryTimeout?.cancel()
        discoveryTimeout = nil
        mobileDataGuidanceDelay?.cancel()
        mobileDataGuidanceDelay = nil
        tunnelAppProbeTask?.cancel()
        tunnelAppProbeTask = nil
        browser.stop()

        for service in discoveredServices {
            service.stopMonitoring()
            service.stop()
            service.remove(from: .main, forMode: .common)
            service.delegate = nil
        }
        discoveredServices = []
    }

    private func verifyServiceIsReachable(_ service: RemotePairingService) {
        guard
            phase == .discovering,
            pendingSession != nil,
            serviceProbeConnection == nil
        else { return }
        guard let port = NWEndpoint.Port(rawValue: service.port) else {
            handleServiceProbeResult(false, service: service)
            return
        }

        serviceProbeAttemptCount += 1
        let connection = NWConnection(
            host: NWEndpoint.Host(service.host),
            port: port,
            using: .tcp
        )
        serviceProbeConnection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let connection else { return }
            switch state {
            case .ready:
                Task { @MainActor [weak self] in
                    self?.finishServiceProbe(connection, service: service, reachable: true)
                }
            case .failed, .cancelled:
                Task { @MainActor [weak self] in
                    self?.finishServiceProbe(connection, service: service, reachable: false)
                }
            case .setup, .waiting, .preparing:
                break
            @unknown default:
                break
            }
        }

        serviceProbeTimeout = Task { @MainActor [weak self, weak connection] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, let self, let connection else { return }
            self.finishServiceProbe(connection, service: service, reachable: false)
        }
        connection.start(queue: serviceProbeQueue)
    }

    private func finishServiceProbe(
        _ connection: NWConnection,
        service: RemotePairingService,
        reachable: Bool
    ) {
        guard serviceProbeConnection === connection else { return }
        serviceProbeConnection = nil
        serviceProbeTimeout?.cancel()
        serviceProbeTimeout = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
        handleServiceProbeResult(reachable, service: service)
    }

    private func handleServiceProbeResult(
        _ reachable: Bool,
        service: RemotePairingService
    ) {
        guard phase == .discovering, pendingSession != nil else { return }

        if reachable {
            serviceProbeAttemptCount = 0
            hasReachedDeviceTunnel = true
            resolvedService = service
            endpointSource = service.endpointSource
            mobileDataDiscoveryLoopTask?.cancel()
            mobileDataDiscoveryLoopTask = nil
            if mobileDataGuidance == .connectionHelp {
                mobileDataGuidance = nil
            }
            cleanupDiscovery()
            submitLocationTask()
            return
        }

        if let fallbackHost = service.fallbackHost, fallbackHost != service.host {
            serviceProbeAttemptCount = 0
            let fallbackService = RemotePairingService(
                host: fallbackHost,
                port: service.port,
                identifier: service.identifier,
                authTag: service.authTag,
                endpointSource: .fallback,
                fallbackHost: nil
            )
            serviceProbeRetryTask?.cancel()
            serviceProbeRetryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                self.serviceProbeRetryTask = nil
                self.verifyServiceIsReachable(fallbackService)
            }
            return
        }

        if !hasOpenedTunnelAppThisAttempt && !hasReachedDeviceTunnel {
            serviceProbeAttemptCount = 0
            openSelectedTunnelAppForPendingSession()
            return
        }

        if isMobileDataStartupMode {
            serviceProbeAttemptCount = 0
            if tunnelHandoffApp == .shadowrocket {
                showConnectionHelp()
            }
            return
        }

        guard serviceProbeAttemptCount < 3 else {
            serviceProbeAttemptCount = 0
            showConnectionHelp()
            return
        }

        serviceProbeRetryTask?.cancel()
        serviceProbeRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, let self else { return }
            self.serviceProbeRetryTask = nil
            self.verifyServiceIsReachable(service)
        }
    }

    private func cleanupServiceProbe() {
        serviceProbeTimeout?.cancel()
        serviceProbeTimeout = nil
        serviceProbeRetryTask?.cancel()
        serviceProbeRetryTask = nil
        serviceProbeConnection?.stateUpdateHandler = nil
        serviceProbeConnection?.cancel()
        serviceProbeConnection = nil
        serviceProbeAttemptCount = 0
    }

    private func clearPendingSession() {
        builtInTunnelStartupTask?.cancel()
        builtInTunnelStartupTask = nil
        builtInTunnelStartupID = nil
        retryTelemetry.reset()
        automaticDiscoveryTask?.cancel()
        automaticDiscoveryTask = nil
        networkDecisionTask?.cancel()
        networkDecisionTask = nil
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        localDevVPNReturnTimeout?.cancel()
        localDevVPNReturnTimeout = nil
        cleanupDiscovery()
        pendingSession = nil
        resolvedService = nil
        backgroundKeepAlive.stop()
        hasOpenedTunnelAppThisAttempt = false
        isMobileDataStartupMode = false
    }

    private func finishCancelledLocationSession() {
        let elapsed = restorationDisplayStartDate.map { Date.now.timeIntervalSince($0) } ?? .infinity
        restorationDisplayStartDate = nil
        let remaining = max(0, Self.minimumRestorationDisplayDuration - elapsed)

        guard remaining > 0 else {
            phase = .idle
            return
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard let self, !self.workerIsRunning, self.phase == .stopping else { return }
            self.phase = .idle
        }
    }

    private func isRecoverableTunnelConnectionFailure(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("through LocalDevVPN")
            || message.localizedCaseInsensitiveContains("make the iPhone connection available")
            || message.localizedCaseInsensitiveContains("open the secure device tunnel")
    }

    private func startBuiltInTunnelForPendingSession() {
        guard pendingSession != nil, !workerIsRunning else { return }
        guard builtInTunnelStartupTask == nil else { return }
        cleanupDiscovery()
        mobileDataGuidance = nil
        hasOpenedTunnelAppThisAttempt = true
        phase = .openingLocalDevVPN
        connectionStage = .openingLocalDevVPN
        let startID = UUID()
        builtInTunnelStartupID = startID
        builtInTunnelStartupTask = Task { @MainActor [weak self] in
            let connected = await BuiltInTunnelManager.shared.startForSession()
            guard let self, self.builtInTunnelStartupID == startID else { return }
            self.builtInTunnelStartupTask = nil
            self.builtInTunnelStartupID = nil
            guard !Task.isCancelled, self.pendingSession != nil,
                  self.phase == .openingLocalDevVPN else {
                BuiltInTunnelManager.shared.stopAfterSession()
                return
            }
            guard connected else {
                self.fail(BuiltInTunnelManager.shared.lastError ?? "WrapPin could not start its built-in tunnel.")
                return
            }
            if self.wifiPathStatusIsKnown && !self.isWiFiPathSatisfied {
                self.isMobileDataStartupMode = true
                self.enterMobileDataGuidance()
            } else {
                self.beginDiscovery(showConnectionHelpIfUnavailable: true)
            }
        }
    }

    private func routeStartupForCurrentNetwork() {
        networkDecisionTask?.cancel()
        networkDecisionTask = nil
        mobileDataGuidance = nil

        if wifiPathStatusIsKnown {
            if TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
                app: tunnelHandoffApp,
                isWiFiPathKnown: wifiPathStatusIsKnown,
                isWiFiSatisfied: isWiFiPathSatisfied
            ) {
                isMobileDataStartupMode = true
                openSelectedTunnelAppForPendingSession()
            } else {
                isMobileDataStartupMode = !isWiFiPathSatisfied
                beginDiscovery(openTunnelAppIfUnavailable: true)
            }
            return
        }

        networkDecisionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard
                !Task.isCancelled,
                let self,
                self.pendingSession != nil,
                !self.workerIsRunning
            else { return }

            self.networkDecisionTask = nil
            if TunnelHandoffPolicy.requiresLocalDevVPNCellularHandoff(
                app: self.tunnelHandoffApp,
                isWiFiPathKnown: self.wifiPathStatusIsKnown,
                isWiFiSatisfied: self.isWiFiPathSatisfied
            ) {
                self.isMobileDataStartupMode = true
                self.openSelectedTunnelAppForPendingSession()
            } else {
                self.isMobileDataStartupMode = self.wifiPathStatusIsKnown && !self.isWiFiPathSatisfied
                self.beginDiscovery(openTunnelAppIfUnavailable: true)
            }
        }
    }

    private func enterMobileDataGuidance() {
        guard pendingSession != nil, !workerIsRunning else { return }
        cleanupDiscovery()
        phase = .discovering
        mobileDataGuidance = .turnOff
        startMobileDataDiscoveryLoop()
    }

    private func resumeAfterTunnelApp() {
        guard pendingSession != nil, !workerIsRunning else { return }
        if tunnelHandoffApp == .shadowrocket && wifiPathStatusIsKnown {
            isMobileDataStartupMode = !isWiFiPathSatisfied
        }
        if isMobileDataStartupMode &&
            TunnelHandoffPolicy.offersMobileDataWorkaround(for: tunnelHandoffApp) {
            enterMobileDataGuidance()
        } else {
            beginDiscovery(showConnectionHelpIfUnavailable: true)
        }
    }

    private func startMobileDataDiscoveryLoop() {
        guard
            isMobileDataStartupMode,
            mobileDataGuidance == .turnOff,
            pendingSession != nil,
            !workerIsRunning
        else { return }

        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard
                    let self,
                    self.isMobileDataStartupMode,
                    self.mobileDataGuidance == .turnOff,
                    self.pendingSession != nil,
                    !self.workerIsRunning
                else { return }

                self.resolvedService = nil
                self.beginDiscovery(reportTimeout: false)
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private func openSelectedTunnelAppForPendingSession() {
#if !targetEnvironment(simulator)
        if usesBuiltInTunnel {
            startBuiltInTunnelForPendingSession()
            return
        }
        guard pendingSession != nil, !workerIsRunning else { return }
        mobileDataDiscoveryLoopTask?.cancel()
        mobileDataDiscoveryLoopTask = nil
        cleanupDiscovery()
        mobileDataGuidance = nil
        hasOpenedTunnelAppThisAttempt = true
        phase = .openingLocalDevVPN
        connectionStage = .openingLocalDevVPN

        UIApplication.shared.open(tunnelHandoffApp.launchURL) { [weak self] opened in
            guard !opened else { return }
            Task { @MainActor in
                self?.fail("Could not open the selected tunnel app. Check that it is installed and supports app links.")
            }
        }
#endif
    }

}

extension LocalDeviceSessionCoordinator: NetServiceBrowserDelegate, NetServiceDelegate {
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
            fail("Local Network access is required to find this iPhone.")
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        MainActor.assumeIsolated {
            useResolvedService(sender)
        }
    }

    nonisolated func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        MainActor.assumeIsolated {
            useResolvedService(sender)
        }
    }
}

private enum NativeLocationOutcome: Sendable {
    case success
    case failure(String)

    init(result: WPLocationResult, returnCode: Int32) {
        guard returnCode != 0 else {
            self = .success
            return
        }

        let message: String
        if let errorMessage = result.error_message {
            message = String(cString: errorMessage)
        } else {
            message = ""
        }
        self = .failure(message.isEmpty ? "The iPhone could not start the location session." : message)
    }
}

private let locationStartedCallback: WPLocationStartedCallback = { context in
    guard let context else { return }
    let contextBits = UInt(bitPattern: context)

    DispatchQueue.main.async {
        guard let context = UnsafeMutableRawPointer(bitPattern: contextBits) else { return }
        let coordinator = Unmanaged<LocalDeviceSessionCoordinator>
            .fromOpaque(context)
            .takeUnretainedValue()
        coordinator.nativeLocationStarted()
    }
}
