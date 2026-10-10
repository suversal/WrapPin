import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let favouritesKey = "favouriteLocations"
    private static let hasSeenFavouriteReorderHintKey = "hasSeenFavouriteReorderHint"
    private static let historyKey = "locationHistory"
    private static let appearanceKey = "appAppearance"
    private static let mapDisplayStyleKey = "mapDisplayStyle"
    private static let tunnelHandoffAppKey = "tunnelHandoffApp"
    private static let usesBuiltInTunnelKey = "usesBuiltInTunnel"
    private static let activeSessionRecoveryKey = "activeSessionRecovery"
    private static let anonymousUsageStatisticsKey = "sharesAnonymousUsageStatistics"

    private let preferences: UserDefaults

    private(set) var hasCompletedOnboarding: Bool
    private(set) var shouldPresentDeviceSetup = false
    private(set) var connectionState: ConnectionState = .notConfigured
    private(set) var pairingStatus: PairingStatus = .checking
    private(set) var selectedTarget: LocationTarget?
    private(set) var favouriteLocations: [LocationTarget]
    private(set) var hasSeenFavouriteReorderHint: Bool
    private(set) var locationHistory: [LocationTarget]
    private(set) var appearance: AppAppearance
    private(set) var mapDisplayStyle: MapDisplayStyle
    private(set) var tunnelHandoffApp: TunnelHandoffApp
    private(set) var usesBuiltInTunnel: Bool
    private(set) var sharesAnonymousUsageStatistics: Bool
    private(set) var interruptedSession: SessionRecoveryRecord?
    private(set) var isRestoringInterruptedSession = false
    private(set) var interruptedSessionError: String?

    private var activeSessionRecovery: SessionRecoveryRecord?
    private var lastRecoverySaveDate: Date?
    private var restorationReachedActiveSession = false
    private var restorationWasCancelled = false
    private var isStoppingLocationSessionForRestoration = false
    private var pendingSessionAnalyticsEvent: UsageAnalyticsEvent?

    var activeFixedCoordinateMode: FixedCoordinateMode? {
        guard
            case .active = deviceSession.phase,
            let recovery = activeSessionRecovery,
            recovery.kind == .fixedLocation
        else { return nil }
        return recovery.fixedCoordinateMode
            ?? FixedCoordinateMode.recommended(for: recovery.lastReportedLocation)
    }

    let pairingService: any PairingService
    let onDevicePairing: OnDevicePairingCoordinator
    let deviceSession: LocalDeviceSessionCoordinator
    private let usageAnalytics: UsageAnalyticsService
    let localDevVPNInstallURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!
    var selectedTunnelAppInstallURL: URL {
        switch tunnelHandoffApp {
        case .localDevVPN: localDevVPNInstallURL
        case .shadowrocket: URL(string: "https://apps.apple.com/app/shadowrocket/id932747118")!
        case .surge: URL(string: "https://apps.apple.com/app/surge-5/id1442620678")!
        }
    }

    init(
        pairingService: any PairingService = SecurePairingService(),
        preferences: UserDefaults = .standard
    ) {
        self.pairingService = pairingService
        self.onDevicePairing = .shared
        self.deviceSession = LocalDeviceSessionCoordinator()
        self.usageAnalytics = UsageAnalyticsService(preferences: preferences)
        self.preferences = preferences
        let hasCompletedOnboarding = preferences.bool(forKey: Self.onboardingKey)
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.favouriteLocations = Self.locations(forKey: Self.favouritesKey, in: preferences)
        self.hasSeenFavouriteReorderHint = preferences.bool(forKey: Self.hasSeenFavouriteReorderHintKey)
        self.locationHistory = Self.locations(forKey: Self.historyKey, in: preferences)
        self.appearance = AppAppearance(
            rawValue: preferences.string(forKey: Self.appearanceKey) ?? ""
        ) ?? .automatic
        self.mapDisplayStyle = MapDisplayStyle(
            rawValue: preferences.string(forKey: Self.mapDisplayStyleKey) ?? ""
        ) ?? .standard
        self.tunnelHandoffApp = TunnelHandoffApp(
            rawValue: preferences.string(forKey: Self.tunnelHandoffAppKey) ?? ""
        ) ?? .localDevVPN
        self.usesBuiltInTunnel = BuildEdition.supportsBuiltInTunnel
            && (preferences.object(forKey: Self.usesBuiltInTunnelKey) as? Bool ?? true)
        self.sharesAnonymousUsageStatistics = Self.initialUsageStatisticsPreference(
            in: preferences
        )
        self.interruptedSession = Self.recoveryRecord(in: preferences)
        self.deviceSession.tunnelHandoffApp = tunnelHandoffApp
        self.deviceSession.usesBuiltInTunnel = usesBuiltInTunnel

        onDevicePairing.onFailure = { [weak self] stage in
            guard let self else { return }
            self.usageAnalytics.recordFailure(stage, context: .pairing, schedulerReason: self.onDevicePairing.schedulerFailureReason, enabled: self.sharesAnonymousUsageStatistics)
        }
        deviceSession.onFailure = { [weak self] stage in
            guard let self else { return }
            let restoring = self.isRestoringInterruptedSession || self.isStoppingLocationSessionForRestoration
            self.usageAnalytics.recordFailure(stage, context: restoring ? .restoration : .location, enabled: self.sharesAnonymousUsageStatistics)
        }

        deviceSession.onRecoveryNeeded = { [weak self] stage in
            guard let self else { return }
            let restoring = self.isRestoringInterruptedSession || self.isStoppingLocationSessionForRestoration
            self.usageAnalytics.recordFailure(stage, context: restoring ? .restoration : .location,
                                              disposition: .recoverable, schedulerReason: stage == .schedulerSubmission ? self.deviceSession.schedulerFailureReason : nil, enabled: self.sharesAnonymousUsageStatistics)
        }
        deviceSession.onConnectionEvent = { [weak self] event in
            guard let self else { return }
            self.usageAnalytics.record(event, enabled: self.sharesAnonymousUsageStatistics)
        }
        deviceSession.onPhaseChange = { [weak self] phase in
            self?.applyDeviceSessionPhase(phase)
        }
        onDevicePairing.onPhaseChange = { [weak self] phase in
            guard case .failed = phase else { return }
            self?.usageAnalytics.record(
                .pairingFailed,
                enabled: self?.sharesAnonymousUsageStatistics ?? false
            )
        }

        if hasCompletedOnboarding {
            usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
        }
    }

    func chooseTarget(_ target: LocationTarget) {
        selectedTarget = target
        addToHistory(target)
    }

    func updateStoredLocationMetadata(with target: LocationTarget) {
        if let index = locationHistory.firstIndex(where: { $0.id == target.id }) {
            locationHistory[index] = mergingStoredName(
                from: locationHistory[index],
                with: target
            )
            save(locationHistory, forKey: Self.historyKey)
        }

        if let index = favouriteLocations.firstIndex(where: { $0.id == target.id }) {
            favouriteLocations[index] = mergingStoredName(
                from: favouriteLocations[index],
                with: target
            )
            save(favouriteLocations, forKey: Self.favouritesKey)
        }

        if let selectedTarget, selectedTarget.id == target.id {
            self.selectedTarget = mergingStoredName(from: selectedTarget, with: target)
        }
    }

    func isFavourite(_ target: LocationTarget) -> Bool {
        favouriteLocations.contains { $0.id == target.id }
    }

    func toggleFavourite(_ target: LocationTarget) {
        if let index = favouriteLocations.firstIndex(where: { $0.id == target.id }) {
            favouriteLocations.remove(at: index)
        } else {
            favouriteLocations.insert(target, at: 0)
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func removeFavourite(_ target: LocationTarget) {
        favouriteLocations.removeAll { $0.id == target.id }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func moveFavouriteLocations(from source: IndexSet, to destination: Int) {
        favouriteLocations.move(fromOffsets: source, toOffset: destination)
        save(favouriteLocations, forKey: Self.favouritesKey)
        dismissFavouriteReorderHint()
    }

    func dismissFavouriteReorderHint() {
        guard !hasSeenFavouriteReorderHint else { return }
        hasSeenFavouriteReorderHint = true
        preferences.set(true, forKey: Self.hasSeenFavouriteReorderHintKey)
    }

    func renameFavourite(_ target: LocationTarget, to proposedName: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            let index = favouriteLocations.firstIndex(where: { $0.id == target.id })
        else { return }

        let renamed = LocationTarget(
            name: name,
            subtitle: target.subtitle,
            latitude: target.latitude,
            longitude: target.longitude
        )
        favouriteLocations[index] = renamed
        if selectedTarget?.id == target.id {
            selectedTarget = renamed
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func removeFromHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        save(locationHistory, forKey: Self.historyKey)
    }

    func clearLocationHistory() {
        locationHistory = []
        preferences.removeObject(forKey: Self.historyKey)
    }

    func clearFavouriteLocations() {
        favouriteLocations = []
        preferences.removeObject(forKey: Self.favouritesKey)
    }

    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        preferences.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    func setMapDisplayStyle(_ style: MapDisplayStyle) {
        mapDisplayStyle = style
        preferences.set(style.rawValue, forKey: Self.mapDisplayStyleKey)
    }

    func setTunnelHandoffApp(_ app: TunnelHandoffApp) {
        tunnelHandoffApp = app
        deviceSession.tunnelHandoffApp = app
        preferences.set(app.rawValue, forKey: Self.tunnelHandoffAppKey)
    }

    func setUsesBuiltInTunnel(_ enabled: Bool) {
        let available = BuildEdition.supportsBuiltInTunnel && enabled
        usesBuiltInTunnel = available
        deviceSession.usesBuiltInTunnel = available
        preferences.set(available, forKey: Self.usesBuiltInTunnelKey)
    }

    func setSharesAnonymousUsageStatistics(_ enabled: Bool) {
        sharesAnonymousUsageStatistics = enabled
        preferences.set(enabled, forKey: Self.anonymousUsageStatisticsKey)

        if enabled, hasCompletedOnboarding {
            usageAnalytics.recordActivation(enabled: true)
        } else if !enabled {
            usageAnalytics.revokeLocalIdentity()
        }
    }

    func completeOnboarding() {
        preferences.set(
            sharesAnonymousUsageStatistics,
            forKey: Self.anonymousUsageStatisticsKey
        )
        preferences.set(true, forKey: Self.onboardingKey)
        shouldPresentDeviceSetup = true
        hasCompletedOnboarding = true
        usageAnalytics.record(
            .onboardingCompleted,
            enabled: sharesAnonymousUsageStatistics
        )
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
    }

    func deviceSetupWasPresented() {
        shouldPresentDeviceSetup = false
    }

    func resetApp() async throws {
        onDevicePairing.reset()
        deviceSession.reset()
        try await pairingService.removeRecord()

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            preferences.removePersistentDomain(forName: bundleIdentifier)
        } else {
            preferences.removeObject(forKey: Self.onboardingKey)
        }

        selectedTarget = nil
        favouriteLocations = []
        locationHistory = []
        appearance = .automatic
        mapDisplayStyle = .standard
        tunnelHandoffApp = .localDevVPN
        deviceSession.tunnelHandoffApp = .localDevVPN
        usesBuiltInTunnel = BuildEdition.supportsBuiltInTunnel
        deviceSession.usesBuiltInTunnel = BuildEdition.supportsBuiltInTunnel
        sharesAnonymousUsageStatistics = false
        interruptedSession = nil
        activeSessionRecovery = nil
        isRestoringInterruptedSession = false
        interruptedSessionError = nil
        restorationWasCancelled = false
        pairingStatus = .notPaired
        connectionState = .notConfigured
        shouldPresentDeviceSetup = false
        hasCompletedOnboarding = false
        usageAnalytics.revokeLocalIdentity()
    }

    func restorePairingStatus() async {
        pairingStatus = .checking

        do {
            if let summary = try await pairingService.storedRecord() {
                pairingStatus = .paired(summary)
                if deviceSession.phase == .idle {
                    connectionState = .ready
                }
            } else {
                pairingStatus = .notPaired
                connectionState = .notConfigured
            }
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.record(.pairingFailed, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.recordFailure(.pairingRead, context: .pairing, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func importPairingRecord(from url: URL) async {
        pairingStatus = .importing

        do {
            let summary = try await pairingService.importRecord(from: url)
            pairingStatus = .paired(summary)
            connectionState = .ready
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.record(.pairingFailed, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.recordFailure(.pairingImport, context: .pairing, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func startOnDevicePairing() {
        onDevicePairing.start { [weak self] record, hostAltIRK in
            guard let self else {
                throw PairingServiceError.corruptStoredRecord
            }

            let summary = try await self.pairingService.storeGeneratedRecord(
                record,
                hostAltIRK: hostAltIRK
            )
            self.pairingStatus = .paired(summary)
            self.connectionState = .ready
            self.usageAnalytics.record(
                .pairingCompleted,
                enabled: self.sharesAnonymousUsageStatistics
            )
            return summary
        }
    }

    func cancelOnDevicePairing() {
        onDevicePairing.cancel()
    }

    func startLocationSession(
        at target: LocationTarget,
        coordinateMode: FixedCoordinateMode
    ) async {
        await startLocationSession(
            at: target,
            selectedTarget: target,
            historyTarget: target,
            recovery: .fixed(at: target, mode: coordinateMode)
        )
    }

    func startRouteLocationSession(
        at initialTarget: LocationTarget,
        destination: LocationTarget,
        mode: RouteMode,
        coordinateMode: FixedCoordinateMode,
        speedMetresPerSecond: Double
    ) async {
        await startLocationSession(
            at: initialTarget,
            selectedTarget: destination,
            historyTarget: destination,
            recovery: .route(
                from: initialTarget,
                to: destination,
                mode: mode,
                coordinateMode: coordinateMode,
                speedMetresPerSecond: speedMetresPerSecond
            )
        )
    }

    private func startLocationSession(
        at deviceTarget: LocationTarget,
        selectedTarget: LocationTarget,
        historyTarget: LocationTarget,
        recovery: SessionRecoveryRecord
    ) async {
        guard case .paired = pairingStatus else {
            connectionState = .notConfigured
            return
        }

        self.selectedTarget = selectedTarget
        dismissInterruptedSessionRecovery()
        activeSessionRecovery = recovery
        lastRecoverySaveDate = nil
        addToHistory(historyTarget)
        let simulationCoordinates = FixedCoordinateTransform.coordinates(
            for: deviceTarget,
            mode: recovery.fixedCoordinateMode
                ?? FixedCoordinateMode.recommended(for: deviceTarget)
        )
        switch deviceSession.updateLocation(
            deviceTarget,
            simulationCoordinates: simulationCoordinates
        ) {
        case .updated:
            usageAnalytics.record(
                .activeLocationUpdated,
                enabled: sharesAnonymousUsageStatistics
            )
            return
        case .failed:
            return
        case .unavailable:
            break
        }

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                activeSessionRecovery = nil
                pendingSessionAnalyticsEvent = nil
                pairingStatus = .notPaired
                connectionState = .notConfigured
                usageAnalytics.recordFailure(.locationPreparation, context: .location, enabled: sharesAnonymousUsageStatistics)
                usageAnalytics.record(
                    .locationPreparationFailed,
                    enabled: sharesAnonymousUsageStatistics
                )
                return
            }
            switch recovery.kind {
            case .walkingRoute: pendingSessionAnalyticsEvent = .walkingStarted
            case .drivingRoute: pendingSessionAnalyticsEvent = .drivingStarted
            case .fixedLocation: pendingSessionAnalyticsEvent = .fixedLocationStarted
            }
            deviceSession.start(
                pairingRecord: pairingRecord,
                target: deviceTarget,
                simulationCoordinates: simulationCoordinates
            )
        } catch {
            activeSessionRecovery = nil
            pendingSessionAnalyticsEvent = nil
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.recordFailure(.locationPreparation, context: .location, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.record(
                .locationPreparationFailed,
                enabled: sharesAnonymousUsageStatistics
            )
        }
    }

    func restoreRealLocationFromInterruptedSession() async {
        guard let recovery = interruptedSession else { return }
        guard case .paired = pairingStatus else {
            interruptedSessionError = String(localized: "Pair this iPhone before restoring its real location.")
            return
        }

        interruptedSessionError = nil
        isRestoringInterruptedSession = true
        restorationReachedActiveSession = false
        restorationWasCancelled = false

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                isRestoringInterruptedSession = false
                interruptedSessionError = String(localized: "The saved pairing record is unavailable. Pair this iPhone again.")
                usageAnalytics.recordFailure(.locationPreparation, context: .restoration, enabled: sharesAnonymousUsageStatistics)
                usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
                return
            }
            deviceSession.start(
                pairingRecord: pairingRecord,
                target: recovery.lastReportedLocation,
                simulationCoordinates: FixedCoordinateTransform.coordinates(
                    for: recovery.lastReportedLocation,
                    mode: recovery.fixedCoordinateMode
                        ?? FixedCoordinateMode.recommended(for: recovery.lastReportedLocation)
                )
            )
        } catch {
            isRestoringInterruptedSession = false
            interruptedSessionError = error.localizedDescription
            usageAnalytics.recordFailure(.locationPreparation, context: .restoration, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func cancelInterruptedSessionRestoration() {
        guard isRestoringInterruptedSession else { return }
        restorationWasCancelled = true
        deviceSession.stop()
    }

    func completeInterruptedSessionRestorationAfterMobileData() {
        guard isRestoringInterruptedSession, restorationReachedActiveSession else { return }
        deviceSession.dismissMobileDataGuidance()
        deviceSession.stop()
    }

    func dismissInterruptedSessionRecovery() {
        interruptedSession = nil
        interruptedSessionError = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    func stopLocationSession() {
        isStoppingLocationSessionForRestoration = true
        deviceSession.stop()
    }

    func handleOpenURL(_ url: URL) {
        deviceSession.handleOpenURL(url)
    }

    func appBecameActive() {
        guard hasCompletedOnboarding else { return }
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
    }

    func removePairingRecord() async {
        onDevicePairing.reset()
        deviceSession.reset()
        do {
            try await pairingService.removeRecord()
            pairingStatus = .notPaired
            connectionState = .notConfigured
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    private func addToHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        locationHistory.insert(target, at: 0)
        locationHistory = Array(locationHistory.prefix(30))
        save(locationHistory, forKey: Self.historyKey)
    }

    private func mergingStoredName(
        from stored: LocationTarget,
        with refreshed: LocationTarget
    ) -> LocationTarget {
        LocationTarget(
            name: stored.usesGenericMapName ? refreshed.name : stored.name,
            subtitle: refreshed.subtitle,
            latitude: stored.latitude,
            longitude: stored.longitude
        )
    }

    private func applyDeviceSessionPhase(_ phase: DeviceSessionPhase) {
        switch phase {
        case .idle:
            pendingSessionAnalyticsEvent = nil
            isStoppingLocationSessionForRestoration = false
            if isRestoringInterruptedSession {
                let didRestore = restorationReachedActiveSession && !restorationWasCancelled
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                if didRestore {
                    dismissInterruptedSessionRecovery()
                }
            }
            clearActiveSessionRecovery()
            if case .paired = pairingStatus {
                connectionState = .ready
            } else {
                connectionState = .notConfigured
            }
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            connectionState = .connecting
        case .active(let target):
            connectionState = .active
            isStoppingLocationSessionForRestoration = false
            if let event = pendingSessionAnalyticsEvent {
                usageAnalytics.record(event, enabled: sharesAnonymousUsageStatistics)
                pendingSessionAnalyticsEvent = nil
            }
            if isRestoringInterruptedSession {
                restorationReachedActiveSession = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard
                        let self,
                        self.isRestoringInterruptedSession,
                        !self.restorationWasCancelled
                    else { return }
                    if self.deviceSession.mobileDataGuidance != .turnBackOn {
                        self.deviceSession.stop()
                    }
                }
            } else {
                persistActiveSessionRecovery(at: target)
            }
        case .failed(let message):
            pendingSessionAnalyticsEvent = nil
            connectionState = .failed(message: message)
            if isRestoringInterruptedSession || isStoppingLocationSessionForRestoration {
                let wasRestoringInterruptedSession = isRestoringInterruptedSession
                if !restorationWasCancelled {
                    usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
                }
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                isStoppingLocationSessionForRestoration = false
                if wasRestoringInterruptedSession {
                    interruptedSessionError = message
                }
            } else {
                usageAnalytics.record(
                    analyticsEvent(forLocationStartFailure: deviceSession.lastFailureStage),
                    enabled: sharesAnonymousUsageStatistics
                )
                if deviceSession.lastFailureStage != .locationRestore {
                    clearActiveSessionRecovery()
                }
            }
        }
    }

    private func analyticsEvent(forLocationStartFailure stage: FailureStage?) -> UsageAnalyticsEvent {
        switch stage {
        case .vpnConnection, .tunnelConnection: .localDevVPNUnreachable
        case .locationPreparation: .locationPreparationFailed
        default: .locationStartFailed
        }
    }

    private func persistActiveSessionRecovery(at target: LocationTarget) {
        guard var recovery = activeSessionRecovery else { return }
        let now = Date.now

        if
            recovery.isRoute,
            let destination = recovery.destination,
            destination.id == target.id
        {
            recovery = .fixed(
                at: destination,
                mode: recovery.fixedCoordinateMode
                    ?? FixedCoordinateMode.recommended(for: destination)
            )
        } else {
            recovery.lastReportedLocation = target
            recovery.updatedAt = now
        }
        activeSessionRecovery = recovery

        let shouldSave = lastRecoverySaveDate == nil
            || now.timeIntervalSince(lastRecoverySaveDate ?? .distantPast) >= 5
            || recovery.kind == .fixedLocation
        guard shouldSave, let data = try? JSONEncoder().encode(recovery) else { return }
        preferences.set(data, forKey: Self.activeSessionRecoveryKey)
        lastRecoverySaveDate = now
    }

    private func clearActiveSessionRecovery() {
        guard activeSessionRecovery != nil else { return }
        activeSessionRecovery = nil
        lastRecoverySaveDate = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    private func save(_ locations: [LocationTarget], forKey key: String) {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        preferences.set(data, forKey: key)
    }

    private static func locations(forKey key: String, in preferences: UserDefaults) -> [LocationTarget] {
        guard
            let data = preferences.data(forKey: key),
            let locations = try? JSONDecoder().decode([LocationTarget].self, from: data)
        else {
            return []
        }
        return locations
    }

    private static func recoveryRecord(in preferences: UserDefaults) -> SessionRecoveryRecord? {
        guard
            let data = preferences.data(forKey: Self.activeSessionRecoveryKey),
            let recovery = try? JSONDecoder().decode(SessionRecoveryRecord.self, from: data)
        else { return nil }
        return recovery
    }

    private static func initialUsageStatisticsPreference(
        in preferences: UserDefaults
    ) -> Bool {
        if preferences.object(forKey: Self.anonymousUsageStatisticsKey) != nil {
            return preferences.bool(forKey: Self.anonymousUsageStatisticsKey)
        }

        // A missing preference is never treated as consent. Existing saved
        // choices continue unchanged when the app is upgraded.
        return false
    }
}

enum PairingStatus: Equatable {
    case checking
    case importing
    case notPaired
    case paired(PairingRecordSummary)
    case failed(message: String)
}

enum ConnectionState: Equatable {
    case notConfigured
    case ready
    case connecting
    case active
    case failed(message: String)
}
