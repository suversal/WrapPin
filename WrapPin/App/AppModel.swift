import AppIntents
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let favouritesKey = "favouriteLocations"
    private static let favouriteCustomRoutesKey = "favouriteCustomRoutes"
    private static let hasSeenFavouriteReorderHintKey = "hasSeenFavouriteReorderHint"
    private static let historyKey = "locationHistory"
    private static let customRouteHistoryKey = "customRouteHistory"
    private static let maximumCustomRouteHistoryCount = 20
    private static let recentSearchQueriesKey = "recentSearchQueries"
    private static let maximumRecentSearchQueriesCount = 6
    private static let coordinateModeMemoryKey = "coordinateModeMemory"
    private static let appearanceKey = "appAppearance"
    private static let mapDisplayStyleKey = "mapDisplayStyle"
    private static let tunnelHandoffAppKey = "tunnelHandoffApp"
    private static let usesBuiltInTunnelKey = "usesBuiltInTunnel"
    private static let activeSessionRecoveryKey = "activeSessionRecovery"
    private static let anonymousUsageStatisticsKey = "sharesAnonymousUsageStatistics"
    private static let reducesBackgroundLocationIndicatorKey = "reducesBackgroundLocationIndicator"

    private let preferences: UserDefaults

    private(set) var hasCompletedOnboarding: Bool
    private(set) var shouldPresentDeviceSetup = false
    private(set) var connectionState: ConnectionState = .notConfigured
    private(set) var pairingStatus: PairingStatus = .checking
    var pairingImportError: String?
    private(set) var selectedTarget: LocationTarget?
    private(set) var favouriteLocations: [LocationTarget]
    private(set) var favouriteCustomRoutes: [SavedCustomRoute]
    private(set) var hasSeenFavouriteReorderHint: Bool
    private(set) var locationHistory: [LocationTarget]
    private(set) var customRouteHistory: [SavedCustomRoute]
    private(set) var recentSearchQueries: [String]
    private(set) var appearance: AppAppearance
    private(set) var mapDisplayStyle: MapDisplayStyle
    private(set) var tunnelHandoffApp: TunnelHandoffApp
    private(set) var usesBuiltInTunnel: Bool
    private(set) var sharesAnonymousUsageStatistics: Bool
    private(set) var reducesBackgroundLocationIndicator: Bool
    private(set) var interruptedSession: SessionRecoveryRecord?
    private(set) var isRestoringInterruptedSession = false
    private(set) var interruptedSessionError: String?
    private(set) var isStartingLocationSession = false
    // Set by App Shortcuts and performed by HomeView with the same code as its buttons.
    var shortcutRequest: ShortcutRequest?

    private var activeSessionRecovery: SessionRecoveryRecord?
    private var pendingSessionRecovery: SessionRecoveryRecord?
    private var pendingLocationStartIdentifier: UUID?
    private var lastRecoverySaveDate: Date?
    private var restorationReachedActiveSession = false
    private var restorationWasCancelled = false
    private var isStoppingLocationSessionForRestoration = false
    private var pendingSessionAnalyticsEvent: UsageAnalyticsEvent?
    private var coordinateModeMemory: CoordinateModeMemory

    var isRunningRouteSession: Bool {
        activeSessionRecovery?.isRoute == true
    }

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
        case .loon: URL(string: "https://apps.apple.com/app/loon/id1373567447")!
        case .stash: URL(string: "https://apps.apple.com/app/stash-rule-based-proxy/id1596063349")!
        case .egern: URL(string: "https://apps.apple.com/app/egern/id1616105820")!
        case .quantumultX: URL(string: "https://apps.apple.com/app/quantumult-x/id1443988620")!
        case .singBox: URL(string: "https://apps.apple.com/app/sing-box-mt/id6785326793")!
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
        self.favouriteCustomRoutes = Self.customRoutes(forKey: Self.favouriteCustomRoutesKey, in: preferences)
        self.hasSeenFavouriteReorderHint = preferences.bool(forKey: Self.hasSeenFavouriteReorderHintKey)
        self.locationHistory = Self.locations(forKey: Self.historyKey, in: preferences)
        self.customRouteHistory = Self.customRoutes(forKey: Self.customRouteHistoryKey, in: preferences)
        self.recentSearchQueries = preferences.stringArray(forKey: Self.recentSearchQueriesKey) ?? []
        self.coordinateModeMemory = Self.coordinateModeMemory(in: preferences)
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
        self.reducesBackgroundLocationIndicator = preferences.bool(
            forKey: Self.reducesBackgroundLocationIndicatorKey
        )
        self.interruptedSession = Self.recoveryRecord(in: preferences)
        self.deviceSession.tunnelHandoffApp = tunnelHandoffApp
        self.deviceSession.usesBuiltInTunnel = usesBuiltInTunnel
        self.deviceSession.backgroundKeepAlive.restoreIndicatorPreference(
            self.reducesBackgroundLocationIndicator
        )

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

    func coordinateMode(for target: LocationTarget) -> FixedCoordinateMode {
        coordinateModeMemory.mode(for: target)
    }

    func rememberManualCoordinateMode(_ mode: FixedCoordinateMode, for target: LocationTarget) {
        coordinateModeMemory.recordManualChoice(mode, for: target)
        saveCoordinateModeMemory()
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

    func renameFavourite(_ target: LocationTarget, to proposedName: String) -> LocationTarget? {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            let index = favouriteLocations.firstIndex(where: { $0.id == target.id })
        else { return nil }

        let renamed = favouriteLocations[index].renamed(to: name)
        favouriteLocations[index] = renamed
        if let selectedTarget, selectedTarget.id == target.id {
            self.selectedTarget = selectedTarget.renamed(to: name)
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
        return renamed
    }

    func removeFromHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        save(locationHistory, forKey: Self.historyKey)
    }

    func clearLocationHistory() {
        locationHistory = []
        preferences.removeObject(forKey: Self.historyKey)
        // The nearby manual choice also holds a recently used coordinate.
        coordinateModeMemory.forgetManualChoice()
        saveCoordinateModeMemory()
    }

    func clearFavouriteLocations() {
        favouriteLocations = []
        preferences.removeObject(forKey: Self.favouritesKey)
        WrapPinShortcuts.updateAppShortcutParameters()
        saveCoordinateModeMemory()
    }

    // MARK: - Saved Custom Routes

    func isFavouriteCustomRoute(_ route: SavedCustomRoute) -> Bool {
        let fingerprint = route.contentFingerprint
        return favouriteCustomRoutes.contains {
            $0.id == route.id || $0.contentFingerprint == fingerprint
        }
    }

    func toggleFavouriteCustomRoute(_ route: SavedCustomRoute) {
        let fingerprint = route.contentFingerprint
        if let index = favouriteCustomRoutes.firstIndex(where: {
            $0.id == route.id || $0.contentFingerprint == fingerprint
        }) {
            favouriteCustomRoutes.remove(at: index)
        } else {
            favouriteCustomRoutes.insert(route, at: 0)
        }
        save(favouriteCustomRoutes, forKey: Self.favouriteCustomRoutesKey)
    }

    func removeFavouriteCustomRoute(_ route: SavedCustomRoute) {
        favouriteCustomRoutes.removeAll { $0.id == route.id }
        save(favouriteCustomRoutes, forKey: Self.favouriteCustomRoutesKey)
    }

    func moveFavouriteCustomRoutes(from source: IndexSet, to destination: Int) {
        favouriteCustomRoutes.move(fromOffsets: source, toOffset: destination)
        save(favouriteCustomRoutes, forKey: Self.favouriteCustomRoutesKey)
        dismissFavouriteReorderHint()
    }

    @discardableResult
    func renameFavouriteCustomRoute(_ route: SavedCustomRoute, to proposedName: String) -> SavedCustomRoute? {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            let index = favouriteCustomRoutes.firstIndex(where: { $0.id == route.id })
        else { return nil }

        let renamed = favouriteCustomRoutes[index].renamed(to: name)
        favouriteCustomRoutes[index] = renamed
        save(favouriteCustomRoutes, forKey: Self.favouriteCustomRoutesKey)
        return renamed
    }

    func clearFavouriteCustomRoutes() {
        favouriteCustomRoutes = []
        preferences.removeObject(forKey: Self.favouriteCustomRoutesKey)
    }

    func recordCustomRouteHistory(_ route: SavedCustomRoute) {
        guard route.points.count >= 2 else { return }
        let fingerprint = route.contentFingerprint
        let existingName = customRouteHistory.first(where: { $0.contentFingerprint == fingerprint })?.name
        let favouriteName = favouriteCustomRoutes.first(where: { $0.contentFingerprint == fingerprint })?.name
        let entry = SavedCustomRoute(
            id: route.id,
            name: favouriteName ?? existingName ?? route.name,
            points: route.points,
            coordinateMode: route.coordinateMode,
            speedKilometresPerHour: route.speedKilometresPerHour,
            updatedAt: .now
        )
        customRouteHistory.removeAll { $0.id == entry.id || $0.contentFingerprint == fingerprint }
        customRouteHistory.insert(entry, at: 0)
        if customRouteHistory.count > Self.maximumCustomRouteHistoryCount {
            customRouteHistory = Array(customRouteHistory.prefix(Self.maximumCustomRouteHistoryCount))
        }
        save(customRouteHistory, forKey: Self.customRouteHistoryKey)
    }

    func removeCustomRouteFromHistory(_ route: SavedCustomRoute) {
        customRouteHistory.removeAll { $0.id == route.id }
        save(customRouteHistory, forKey: Self.customRouteHistoryKey)
    }

    func clearCustomRouteHistory() {
        customRouteHistory = []
        preferences.removeObject(forKey: Self.customRouteHistoryKey)
    }

    // MARK: - Recent Search Queries

    func recordSearchQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearchQueries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearchQueries.insert(trimmed, at: 0)
        if recentSearchQueries.count > Self.maximumRecentSearchQueriesCount {
            recentSearchQueries = Array(recentSearchQueries.prefix(Self.maximumRecentSearchQueriesCount))
        }
        preferences.set(recentSearchQueries, forKey: Self.recentSearchQueriesKey)
    }

    func removeRecentSearchQuery(_ query: String) {
        recentSearchQueries.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        preferences.set(recentSearchQueries, forKey: Self.recentSearchQueriesKey)
    }

    func clearRecentSearchQueries() {
        recentSearchQueries = []
        preferences.removeObject(forKey: Self.recentSearchQueriesKey)
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

    func setReducesBackgroundLocationIndicator(_ enabled: Bool) {
        guard enabled != reducesBackgroundLocationIndicator else { return }
        reducesBackgroundLocationIndicator = enabled
        preferences.set(enabled, forKey: Self.reducesBackgroundLocationIndicatorKey)
        deviceSession.backgroundKeepAlive.setIndicatorPreferenceFromUserAction(enabled)
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

    private(set) var isResettingPairing = false
    private var pairingRevision = 0
    private var pairingImportsInFlight = 0
    private var pairingImportWaiters: [CheckedContinuation<Void, Never>] = []

    private func waitForPairingImports() async {
        if pairingImportsInFlight > 0 {
            await withCheckedContinuation { pairingImportWaiters.append($0) }
        }
    }

    private func pairingImportFinished() {
        pairingImportsInFlight -= 1
        guard pairingImportsInFlight == 0 else { return }
        let waiters = pairingImportWaiters
        pairingImportWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    func resetApp() async throws {
        guard !isResettingPairing else { return }
        isResettingPairing = true
        pairingRevision += 1
        defer { isResettingPairing = false }
        _ = cancelPendingLocationPreparation()
        await onDevicePairing.reset()
        await waitForPairingImports()
        await deviceSession.resetAndWait()
        try await pairingService.removeRecord()

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            preferences.removePersistentDomain(forName: bundleIdentifier)
        } else {
            preferences.removeObject(forKey: Self.onboardingKey)
        }

        selectedTarget = nil
        favouriteLocations = []
        favouriteCustomRoutes = []
        locationHistory = []
        customRouteHistory = []
        recentSearchQueries = []
        coordinateModeMemory = CoordinateModeMemory()
        shortcutRequest = nil
        WrapPinShortcuts.updateAppShortcutParameters()
        appearance = .automatic
        mapDisplayStyle = .standard
        tunnelHandoffApp = .localDevVPN
        deviceSession.tunnelHandoffApp = .localDevVPN
        usesBuiltInTunnel = BuildEdition.supportsBuiltInTunnel
        deviceSession.usesBuiltInTunnel = BuildEdition.supportsBuiltInTunnel
        sharesAnonymousUsageStatistics = false
        reducesBackgroundLocationIndicator = false
        deviceSession.backgroundKeepAlive.restoreIndicatorPreference(false)
        interruptedSession = nil
        activeSessionRecovery = nil
        pendingSessionRecovery = nil
        pendingLocationStartIdentifier = nil
        isStartingLocationSession = false
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
        guard !isResettingPairing else { return }
        let revision = pairingRevision
        pairingStatus = .checking

        do {
            let summary = try await pairingService.storedRecord()
            guard revision == pairingRevision else { return }
            if let summary {
                pairingStatus = .paired(summary)
                if deviceSession.phase == .idle {
                    connectionState = .ready
                }
            } else {
                pairingStatus = .notPaired
                connectionState = .notConfigured
            }
        } catch {
            guard revision == pairingRevision else { return }
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
            usageAnalytics.record(.pairingFailed, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.recordFailure(.pairingRead, context: .pairing, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func importPairingRecord(from url: URL) async {
        await importPairingRecord { try await self.pairingService.importRecord(from: url) }
    }

    func importPairingRecord(data: Data) async {
        await importPairingRecord { try await self.pairingService.importRecord(data: data) }
    }

    private func importPairingRecord(using operation: () async throws -> PairingRecordSummary) async {
        guard !isChangingPairingUnavailable else {
            pairingImportError = String(localized: "Stop the current session before changing its pairing file.")
            return
        }
        pairingImportsInFlight += 1
        defer { pairingImportFinished() }
        let previousStatus = pairingStatus
        let previousConnection = connectionState
        pairingImportError = nil
        pairingStatus = .importing

        do {
            let summary = try await operation()
            guard !isResettingPairing else { return }
            await onDevicePairing.reset()
            guard !isResettingPairing else { return }
            pairingStatus = .paired(summary)
            connectionState = .ready
        } catch {
            guard !isResettingPairing else { return }
            let message = error.localizedDescription
            pairingImportError = message
            if case .paired = previousStatus {
                pairingStatus = previousStatus
                connectionState = previousConnection
            } else {
                pairingStatus = .failed(message: message)
                connectionState = .failed(message: message)
            }
            usageAnalytics.record(.pairingFailed, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.recordFailure(.pairingImport, context: .pairing, enabled: sharesAnonymousUsageStatistics)
        }
    }

    var isChangingPairingUnavailable: Bool {
        isResettingPairing || pairingStatus == .checking || pairingStatus == .importing
            || onDevicePairing.isRunning || deviceSession.isBusy
            || connectionState == .active || isStartingLocationSession || isRestoringInterruptedSession
    }

    func startOnDevicePairing() {
        guard !isChangingPairingUnavailable else { return }
        onDevicePairing.start { [weak self] record, hostAltIRK in
            guard let self else {
                throw PairingServiceError.corruptStoredRecord
            }

            let summary = try await self.pairingService.storeGeneratedRecord(
                record,
                hostAltIRK: hostAltIRK
            )
            guard !self.isResettingPairing else { return summary }
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
        speedMetresPerSecond: Double,
        customRoutePoints: [SavedRoutePoint]? = nil
    ) async {
        var record = SessionRecoveryRecord.route(
            from: initialTarget, to: destination, mode: mode,
            coordinateMode: coordinateMode, speedMetresPerSecond: speedMetresPerSecond)
        record.customRoutePoints = customRoutePoints
        record.nextCustomRoutePointIndex = customRoutePoints == nil ? nil : 1
        await startLocationSession(
            at: initialTarget,
            selectedTarget: destination,
            historyTarget: destination,
            recovery: record
        )
    }

    func recordCustomRouteProgress(nextPointIndex: Int, at target: LocationTarget) {
        guard activeSessionRecovery?.customRoutePoints != nil else { return }
        activeSessionRecovery?.nextCustomRoutePointIndex = nextPointIndex
        persistActiveSessionRecovery(at: target)
    }

    private func startLocationSession(
        at deviceTarget: LocationTarget,
        selectedTarget: LocationTarget,
        historyTarget: LocationTarget,
        recovery: SessionRecoveryRecord
    ) async {
        guard !isStartingLocationSession, !isRestoringInterruptedSession, !deviceSession.isBusy else { return }
        guard !isResettingPairing else { return }
        guard case .paired = pairingStatus else {
            connectionState = .notConfigured
            return
        }

        // Establish the background request before even the async Keychain read;
        // the user can switch away while that read or the tunnel setup is pending.
        deviceSession.backgroundKeepAlive.start()
        self.selectedTarget = selectedTarget
        interruptedSessionError = nil
        pendingSessionRecovery = recovery
        isStartingLocationSession = true
        let startIdentifier = UUID()
        pendingLocationStartIdentifier = startIdentifier
        if recovery.customRoutePoints == nil {
            addToHistory(historyTarget)
        }
        if let mode = recovery.fixedCoordinateMode {
            coordinateModeMemory.recordUse(mode, for: historyTarget)
            saveCoordinateModeMemory()
        }
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
            // Updating the same target need not emit a phase change.
            activatePendingSessionRecovery(at: deviceTarget)
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
            let pairingRecord = try await pairingService.pairingRecordData()
            guard pendingLocationStartIdentifier == startIdentifier else { return }
            guard let pairingRecord else {
                deviceSession.backgroundKeepAlive.stop()
                preserveRecoveryAfterFailure(stage: .locationPreparation, isStoppingOrRestoring: false)
                isStartingLocationSession = false
                pendingSessionAnalyticsEvent = nil
                pairingStatus = .notPaired
                connectionState = .notConfigured
                if interruptedSession != nil {
                    interruptedSessionError = String(localized: "The saved pairing record is unavailable. Pair this iPhone again.")
                }
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
            guard pendingLocationStartIdentifier == startIdentifier else { return }
            deviceSession.backgroundKeepAlive.stop()
            preserveRecoveryAfterFailure(stage: .locationPreparation, isStoppingOrRestoring: false)
            isStartingLocationSession = false
            if interruptedSession != nil { interruptedSessionError = error.localizedDescription }
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
        guard !isStartingLocationSession, !isRestoringInterruptedSession, !deviceSession.isBusy else { return }
        guard let recovery = interruptedSession else { return }
        guard !isResettingPairing else { return }
        guard case .paired = pairingStatus else {
            interruptedSessionError = String(localized: "Pair this iPhone before restoring its real location.")
            return
        }

        interruptedSessionError = nil
        isRestoringInterruptedSession = true
        restorationReachedActiveSession = false
        restorationWasCancelled = false
        let startIdentifier = UUID()
        pendingLocationStartIdentifier = startIdentifier

        do {
            let pairingRecord = try await pairingService.pairingRecordData()
            guard pendingLocationStartIdentifier == startIdentifier else { return }
            guard let pairingRecord else {
                isRestoringInterruptedSession = false
                pendingLocationStartIdentifier = nil
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
                ),
                allowsAutomaticReconnect: false
            )
        } catch {
            guard pendingLocationStartIdentifier == startIdentifier else { return }
            isRestoringInterruptedSession = false
            pendingLocationStartIdentifier = nil
            interruptedSessionError = error.localizedDescription
            usageAnalytics.recordFailure(.locationPreparation, context: .restoration, enabled: sharesAnonymousUsageStatistics)
            usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
        }
    }

    func cancelInterruptedSessionRestoration() {
        guard isRestoringInterruptedSession else { return }
        restorationWasCancelled = true
        if cancelPendingLocationPreparation() {
            isRestoringInterruptedSession = false
            restorationWasCancelled = false
            return
        }
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
        if cancelPendingLocationPreparation() { return }
        isStoppingLocationSessionForRestoration = true
        deviceSession.stop()
    }

    private func cancelPendingLocationPreparation() -> Bool {
        guard pendingLocationStartIdentifier != nil else { return false }
        switch deviceSession.phase {
        case .idle, .failed:
            // Cancel the suspended pairing read without deleting the old record.
            deviceSession.backgroundKeepAlive.stop()
            pendingLocationStartIdentifier = nil
            pendingSessionRecovery = nil
            isStartingLocationSession = false
            return true
        default:
            return false
        }
    }

    func handleOpenURL(_ url: URL) {
        deviceSession.handleOpenURL(url)
    }

    func appBecameActive() {
        guard hasCompletedOnboarding else { return }
        // Refresh the displayed permission even without an active simulation.
        // reconcile never asks for Always access.
        deviceSession.backgroundKeepAlive.reconcile()
        usageAnalytics.recordActivation(enabled: sharesAnonymousUsageStatistics)
    }

    func removePairingRecord() async {
        guard !isResettingPairing else { return }
        isResettingPairing = true
        pairingRevision += 1
        defer { isResettingPairing = false }
        _ = cancelPendingLocationPreparation()
        await onDevicePairing.reset()
        await waitForPairingImports()
        await deviceSession.resetAndWait()
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
            longitude: stored.longitude,
            isCustomName: stored.isCustomName
        )
    }

    private func applyDeviceSessionPhase(_ phase: DeviceSessionPhase) {
        switch phase {
        case .idle:
            pendingSessionAnalyticsEvent = nil
            isStoppingLocationSessionForRestoration = false
            isStartingLocationSession = false
            if isRestoringInterruptedSession {
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
            }
            if deviceSession.didConfirmLocationClear {
                clearConfirmedSessionRecovery()
            } else if activeSessionRecovery != nil {
                preserveRecoveryAfterFailure(stage: nil, isStoppingOrRestoring: true)
            }
            // Cancelling before any write does not resolve an older record.
            activeSessionRecovery = nil
            pendingSessionRecovery = nil
            pendingLocationStartIdentifier = nil
            lastRecoverySaveDate = nil
            if case .paired = pairingStatus {
                connectionState = .ready
            } else {
                connectionState = .notConfigured
            }
        case .openingLocalDevVPN, .discovering, .connecting:
            connectionState = .connecting
        case .stopping:
            connectionState = .connecting
            isStoppingLocationSessionForRestoration = true
        case .active(let target):
            connectionState = .active
            isStoppingLocationSessionForRestoration = false
            pendingLocationStartIdentifier = nil
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
                activatePendingSessionRecovery(at: target)
            }
        case .failed(let message):
            pendingSessionAnalyticsEvent = nil
            connectionState = .failed(message: message)
            if deviceSession.didConfirmLocationClear {
                clearConfirmedSessionRecovery()
                return
            }
            let wasStoppingOrRestoring = isRestoringInterruptedSession || isStoppingLocationSessionForRestoration
            preserveRecoveryAfterFailure(
                stage: deviceSession.lastFailureStage,
                isStoppingOrRestoring: wasStoppingOrRestoring
            )
            isStartingLocationSession = false
            if interruptedSession != nil { interruptedSessionError = message }
            if isRestoringInterruptedSession || isStoppingLocationSessionForRestoration {
                if !restorationWasCancelled {
                    usageAnalytics.record(.locationRestoreFailed, enabled: sharesAnonymousUsageStatistics)
                }
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                isStoppingLocationSessionForRestoration = false
            } else {
                usageAnalytics.record(
                    analyticsEvent(forLocationStartFailure: deviceSession.lastFailureStage),
                    enabled: sharesAnonymousUsageStatistics
                )
            }
        }
    }

    private func clearConfirmedSessionRecovery() {
        dismissInterruptedSessionRecovery()
        clearActiveSessionRecovery()
        pendingSessionRecovery = nil
        pendingLocationStartIdentifier = nil
        lastRecoverySaveDate = nil
        isStartingLocationSession = false
        isRestoringInterruptedSession = false
        isStoppingLocationSessionForRestoration = false
        restorationReachedActiveSession = false
        restorationWasCancelled = false
    }

    private func activatePendingSessionRecovery(at target: LocationTarget) {
        if let pendingSessionRecovery {
            activeSessionRecovery = pendingSessionRecovery
            self.pendingSessionRecovery = nil
            lastRecoverySaveDate = nil
        }
        // The new session has reached .active: only now may it replace the old record.
        persistActiveSessionRecovery(at: target)
        interruptedSession = nil
        interruptedSessionError = nil
        isStartingLocationSession = false
        pendingLocationStartIdentifier = nil
    }

    private func preserveRecoveryAfterFailure(stage: FailureStage?, isStoppingOrRestoring: Bool) {
        let recovery = SessionRecoveryPolicy.recordAfterFailure(
            failureStage: stage,
            existingUnconfirmedRecord: interruptedSession,
            activeRecord: activeSessionRecovery,
            pendingRecord: pendingSessionRecovery,
            isStoppingOrRestoring: isStoppingOrRestoring,
            didConfirmLocationClear: deviceSession.didConfirmLocationClear
        )
        if let recovery {
            // Force-save the latest in-memory route point, bypassing the five-second throttle.
            if let data = try? JSONEncoder().encode(recovery) {
                preferences.set(data, forKey: Self.activeSessionRecoveryKey)
            }
            interruptedSession = recovery
        } else {
            clearActiveSessionRecovery()
        }
        activeSessionRecovery = nil
        pendingSessionRecovery = nil
        pendingLocationStartIdentifier = nil
        lastRecoverySaveDate = nil
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
            destination.id == target.id,
            recovery.customRoutePoints == nil
                || (recovery.nextCustomRoutePointIndex ?? 0) >= (recovery.customRoutePoints?.count ?? 0)
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
        if key == Self.favouritesKey {
            // Siri phrases that name a favourite read the current list.
            WrapPinShortcuts.updateAppShortcutParameters()
        }
        // Saved lists changed, so drop mode choices for places no longer stored.
        saveCoordinateModeMemory()
    }

    private func saveCoordinateModeMemory() {
        let storedIDs = Set((favouriteLocations + locationHistory).map(\.id))
        coordinateModeMemory.retainPlaces(withIDs: storedIDs)
        guard let data = try? JSONEncoder().encode(coordinateModeMemory) else { return }
        preferences.set(data, forKey: Self.coordinateModeMemoryKey)
    }

    private static func coordinateModeMemory(in preferences: UserDefaults) -> CoordinateModeMemory {
        guard
            let data = preferences.data(forKey: Self.coordinateModeMemoryKey),
            let memory = try? JSONDecoder().decode(CoordinateModeMemory.self, from: data)
        else { return CoordinateModeMemory() }
        return memory
    }

    private func save(_ routes: [SavedCustomRoute], forKey key: String) {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        preferences.set(data, forKey: key)
    }

    private static func customRoutes(forKey key: String, in preferences: UserDefaults) -> [SavedCustomRoute] {
        guard
            let data = preferences.data(forKey: key),
            let routes = try? JSONDecoder().decode([SavedCustomRoute].self, from: data)
        else {
            return []
        }
        return routes
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
