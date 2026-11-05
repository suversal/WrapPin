import MapKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(ReleaseUpdateModel.self) private var releaseUpdates
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var mapControlSymbolSize = 17
    @State private var mapModel = MapViewModel()
    @State private var walkingRoutePlanner = WalkingRoutePlanner()
    @State private var walkingSimulation = WalkingSimulationController()
    @State private var isShowingDeviceSetup: Bool
    @State private var isShowingSettings: Bool
    @State private var isShowingSavedPlaces = false
    @State private var shouldRefreshRealLocationWhenActive = false
    @State private var shouldClearLocationAfterRestoration = false
    @State private var isLocatingRealLocationAfterRestoration = false
    @State private var visibleMapCamera: MapCamera?
    @State private var isPreparingRecoveredWalk = false
    @State private var recoveredWalkPreparationIdentifier: UUID?
    @State private var recoveredWalkError: String?
    @State private var followsSimulatedLocation = false
    @State private var fixedCoordinateMode: FixedCoordinateMode = .wgs84
    @FocusState private var isSearchFocused: Bool

    init(
        showDeviceSetupInitially: Bool = false,
        showSettingsInitially: Bool = false
    ) {
        _isShowingDeviceSetup = State(initialValue: showDeviceSetupInitially)
        _isShowingSettings = State(initialValue: showSettingsInitially)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if geometry.size.width >= 900 {
                    HStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 16) {
                                searchPanel
                                if !isSearchingForLocation {
                                    statusPanel
                                    backgroundWarning
                                    selectionCard
                                }
                            }
                            .padding(16)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .frame(width: min(400, max(360, geometry.size.width * 0.3)))
                        .background(Color(uiColor: .systemGroupedBackground))
                        .accessibilityIdentifier("map.sidebar")

                        mapContent
                            .overlay(alignment: .bottomTrailing) {
                                mapControls
                                    .padding(16)
                            }
                    }
                } else {
                    mapContent
                    compactControls(availableHeight: geometry.size.height)
                }

                sessionOverlays
            }
        }
        .task {
            await appModel.restorePairingStatus()
            if let interruptedLocation = appModel.interruptedSession?.lastReportedLocation {
                mapModel.center(on: interruptedLocation)
            }
            mapModel.prepareCurrentLocation(
                recenter: appModel.interruptedSession == nil
            )
            if isShowingDeviceSetup {
                appModel.deviceSetupWasPresented()
            }
        }
        .onChange(of: appModel.shortcutRequest?.id, initial: true) {
            handleShortcutRequest()
        }
        .onChange(of: appModel.deviceSession.phase) { oldPhase, newPhase in
            walkingSimulation.handleDeviceSessionPhase(
                newPhase,
                deviceSession: appModel.deviceSession
            )

            switch newPhase {
            case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
                shouldRefreshRealLocationWhenActive = false
                mapModel.invalidateRealLocationCache()
            case .idle:
                if oldPhase == .stopping, shouldClearLocationAfterRestoration {
                    shouldClearLocationAfterRestoration = false
                    walkingSimulation.reset()
                    walkingRoutePlanner.clear()
                    mapModel.clearSelectedLocation()
                    shouldRefreshRealLocationWhenActive = false
                    isLocatingRealLocationAfterRestoration = true
                    mapModel.refreshRealLocationAfterRestoration()
                }
            case .failed:
                shouldClearLocationAfterRestoration = false
            }

            guard oldPhase == .stopping, newPhase == .idle else { return }
            guard !isLocatingRealLocationAfterRestoration else { return }
            shouldRefreshRealLocationWhenActive = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard shouldRefreshRealLocationWhenActive, scenePhase == .active else { return }
                shouldRefreshRealLocationWhenActive = false
                guard case .idle = appModel.deviceSession.phase else { return }
                mapModel.showRealLocationAfterSession()
            }
        }
        .onChange(of: walkingSimulation.distanceTravelled) { _, _ in
            guard followsSimulatedLocation,
                  walkingSimulation.mode == .driving,
                  let coordinate = walkingSimulation.currentCoordinate else { return }
            mapModel.center(on: coordinate)
        }
        .onChange(of: mapModel.selectedLocation?.id) { _, selectedLocationID in
            if let selectedLocation = mapModel.selectedLocation {
                if
                    case .active(let activeTarget) = appModel.deviceSession.phase,
                    activeTarget.id == selectedLocation.id,
                    let activeMode = appModel.activeFixedCoordinateMode
                {
                    fixedCoordinateMode = activeMode
                } else {
                    fixedCoordinateMode = appModel.coordinateMode(for: selectedLocation)
                }
            }
            guard !walkingSimulation.locksDestination else { return }
            guard let destination = walkingRoutePlanner.destination else { return }
            if destination.id != selectedLocationID {
                walkingSimulation.reset()
                walkingRoutePlanner.clear()
            }
        }
        .onChange(of: mapModel.isFindingRealLocation) { _, isFindingRealLocation in
            guard isLocatingRealLocationAfterRestoration, !isFindingRealLocation else { return }
            isLocatingRealLocationAfterRestoration = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            appModel.deviceSession.appDidBecomeActive()

            guard shouldRefreshRealLocationWhenActive else { return }
            shouldRefreshRealLocationWhenActive = false
            guard case .idle = appModel.deviceSession.phase else { return }
            mapModel.showRealLocationAfterSession()
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environment(appModel)
        }
        .sheet(isPresented: $isShowingSavedPlaces) {
            SavedPlacesView(
                favourites: appModel.favouriteLocations,
                history: appModel.locationHistory,
                shouldShowFavouriteReorderHint: !appModel.hasSeenFavouriteReorderHint,
                isFavourite: appModel.isFavourite,
                onSelect: { target in
                    guard !walkingSimulation.locksDestination else { return }
                    mapModel.show(target)
                    Task {
                        guard let refreshed = await mapModel.refreshAddressIfNeeded(for: target) else {
                            return
                        }
                        appModel.updateStoredLocationMetadata(with: refreshed)
                    }
                },
                onToggleFavourite: appModel.toggleFavourite,
                onDeleteFavourite: appModel.removeFavourite,
                onMoveFavourites: appModel.moveFavouriteLocations,
                onDismissFavouriteReorderHint: appModel.dismissFavouriteReorderHint,
                onRenameFavourite: appModel.renameFavourite,
                onDeleteHistory: appModel.removeFromHistory,
                onClearFavourites: appModel.clearFavouriteLocations,
                onClearHistory: appModel.clearLocationHistory
            )
        }
    }

    // Use the available window width so rotation and iPad window resizing use
    // the same layout rules. Session state stays in the shared models above.
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $mapModel.cameraPosition) {
                // Draw the alternatives first so the selected route stays on top.
                ForEach(
                    Array(walkingRoutePlanner.routes.enumerated()),
                    id: \.offset
                ) { index, alternative in
                    if index != walkingRoutePlanner.selectedRouteIndex {
                        MapPolyline(alternative)
                            .stroke(.blue.opacity(0.35), lineWidth: 5)
                    }
                }

                if let route = walkingRoutePlanner.route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 6)
                }

                if shouldShowRealLocation {
                    UserAnnotation()
                }

                if let target = mapModel.selectedLocation {
                    Marker(target.name, coordinate: target.coordinate)
                        .tint(.blue)
                }

                if let coordinate = walkingSimulation.currentCoordinate {
                    Annotation("Simulated route location", coordinate: coordinate) {
                        Image(systemName: walkingSimulation.mode == .walking ? "figure.walk.circle.fill" : "car.circle.fill")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.white, .green)
                            .padding(4)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
                    }
                }
            }
            .roamControlMapStyle(appModel.mapDisplayStyle)
            .mapControls {
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                visibleMapCamera = context.camera
            }
            .onTapGesture { point in
                if isSearchFocused {
                    isSearchFocused = false
                    return
                }

                guard !walkingSimulation.locksDestination else { return }
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                if selectPreviewedRoute(at: point, coordinate: coordinate, proxy: proxy) { return }
                Task { await mapModel.selectDroppedPin(at: coordinate) }
            }
        }
        .ignoresSafeArea()
    }

    private func compactControls(availableHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            searchPanel
            if !isSearchingForLocation {
                statusPanel
                Spacer(minLength: 0)
                backgroundWarning
                mapControls
                ViewThatFits(in: .vertical) {
                    selectionCard
                    ScrollView {
                        selectionCard
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxHeight: max(160, availableHeight * 0.6))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchPanel: some View {
        VStack(spacing: 12) {
            MapSearchBar(
                query: Binding(
                    get: { mapModel.searchQuery },
                    set: { mapModel.updateSearchQuery($0) }
                ),
                isFocused: $isSearchFocused,
                isSearching: mapModel.isSearching,
                isOverseasSearch: mapModel.isOverseasSearchAvailable
                    ? mapModel.isOverseasSearch
                    : nil,
                onToggleOverseasSearch: {
                    mapModel.setOverseasSearch(!mapModel.isOverseasSearch)
                },
                onSubmit: {
                    Task { await mapModel.search() }
                },
                onClear: mapModel.clearSearch
            )
            .disabled(walkingSimulation.locksDestination)

            if mapModel.isShowingSuggestions && !walkingSimulation.locksDestination {
                SearchSuggestionsView(
                    suggestions: mapModel.searchSuggestions,
                    onSelect: { suggestion in
                        isSearchFocused = false
                        Task { await mapModel.selectSuggestion(suggestion) }
                    }
                )
            }

            if mapModel.isShowingOverseasResults && !walkingSimulation.locksDestination {
                OverseasResultsView(
                    places: mapModel.overseasResults,
                    onSelect: { place in
                        isSearchFocused = false
                        mapModel.selectOverseasPlace(place)
                    }
                )
            }
        }
    }

    private var statusPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    isShowingDeviceSetup = true
                } label: {
                    ConnectionBadge(state: appModel.connectionState)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens device pairing setup")

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        isShowingSavedPlaces = true
                    } label: {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: min(mapControlSymbolSize, 24), weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Favourites and history")

                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: min(mapControlSymbolSize, 24), weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
            }

            if let release = releaseUpdates.visibleRelease {
                HStack(spacing: 8) {
                    Link(destination: release.releaseURL) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(
                                    format: NSLocalizedString("WrapPin %@ is available.", comment: ""),
                                    release.version
                                ))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                                Text("View release and download")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: releaseUpdates.dismissBanner) {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss update reminder")
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }

            if needsPairingPrompt {
            Button {
                isShowingDeviceSetup = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pair this device")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Required before location control")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var backgroundWarning: some View {
        if case .active = appModel.deviceSession.phase,
           !appModel.deviceSession.backgroundKeepAlive.started,
           appModel.deviceSession.backgroundKeepAlive.status != .awaitingAuthorization {
            Label(
                "The current simulation can still work in the foreground, but background continuity is unavailable. Check Location access for WrapPin in Settings.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var mapControls: some View {
        HStack {
        Spacer()

        VStack(spacing: 10) {
            if walkingSimulation.mode == .driving,
               let coordinate = walkingSimulation.currentCoordinate,
               let route = walkingRoutePlanner.route {
                Button {
                    followsSimulatedLocation.toggle()
                    if followsSimulatedLocation {
                        mapModel.center(on: coordinate)
                    } else {
                        mapModel.show(route)
                    }
                } label: {
                    Image(systemName: followsSimulatedLocation ? "car.fill" : "car")
                        .font(.system(size: min(mapControlSymbolSize, 24), weight: .semibold))
                        .foregroundStyle(followsSimulatedLocation ? .blue : .primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(followsSimulatedLocation
                    ? "Show whole route"
                    : "Follow simulated car")
            }

            if shouldShowMapCompass {
                Button(action: resetMapHeading) {
                    CompassRoseDial()
                        .rotationEffect(.degrees(-normalisedMapHeading))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Return map to north")
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            if canRequestRealLocation {
                Button {
                    showCurrentLocationNorthUp()
                } label: {
                    Group {
                        if mapModel.isFindingRealLocation {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: min(mapControlSymbolSize, 24), weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(mapModel.isFindingRealLocation)
                .accessibilityLabel("Show my current location")
            }
        }
        }
    }

    @ViewBuilder
    private var selectionCard: some View {
         if isLocatingRealLocationAfterRestoration {
         RestoringRealLocationCard()
         } else if let route = walkingRoutePlanner.route,
        let destination = walkingRoutePlanner.destination {
         WalkingRoutePreviewCard(
             route: route,
             routes: walkingRoutePlanner.routes,
             selectedRouteIndex: walkingRoutePlanner.selectedRouteIndex,
             destination: walkingSimulation.destination ?? destination,
             simulation: walkingSimulation,
             isPaired: isPaired,
             onSelectRoute: selectPreviewedRoute,
             onStart: {
                 walkingRoutePlanner.discardAlternativeRoutes()
                 followsSimulatedLocation = walkingSimulation.mode == .driving
                 Task { await walkingSimulation.start(using: appModel) }
             },
             onTogglePause: walkingSimulation.togglePause,
             onWalkBack: {
                 guard let returnTarget = walkingSimulation.prepareReturnTrip() else { return }
                 walkingRoutePlanner.retargetExistingRoute(to: returnTarget)
                 mapModel.show(returnTarget)
             },
             onChooseNewLocation: {
                 walkingSimulation.reset()
                 walkingRoutePlanner.clear()
                 mapModel.clearSelectedLocation()
             },
             onStop: {
                 shouldClearLocationAfterRestoration = true
                 walkingSimulation.stop(using: appModel.deviceSession)
             },
             onDone: {
                 walkingSimulation.reset()
                 walkingRoutePlanner.clear()
                 mapModel.show(destination)
             }
         )
         } else {
         LocationSelectionCard(
             location: mapModel.selectedLocation,
             isFavourite: mapModel.selectedLocation.map(appModel.isFavourite) ?? false,
             isResolvingAddress: mapModel.isResolvingAddress,
             isPaired: isPaired,
             sessionPhase: appModel.deviceSession.phase,
             tunnelHandoffApp: appModel.tunnelHandoffApp,
             usesBuiltInTunnel: appModel.usesBuiltInTunnel,
             tunnelAppInstallURL: appModel.selectedTunnelAppInstallURL,
             previewingRouteMode: walkingRoutePlanner.isLoading ? walkingRoutePlanner.mode : nil,
             routeError: walkingRoutePlanner.errorMessage,
             coordinateMode: fixedCoordinateMode,
             recommendedCoordinateMode: mapModel.selectedLocation.map(
                 FixedCoordinateMode.recommended
             ) ?? .wgs84,
             onCoordinateModeChange: { mode in
                 fixedCoordinateMode = mode
                 if let target = mapModel.selectedLocation {
                     appModel.rememberManualCoordinateMode(mode, for: target)
                 }
                 guard
                     let target = mapModel.selectedLocation,
                     case .active(let activeTarget) = appModel.deviceSession.phase,
                     activeTarget.id == target.id,
                     appModel.activeFixedCoordinateMode != mode
                 else { return }
                 Task {
                     await appModel.startLocationSession(
                         at: target,
                         coordinateMode: mode
                     )
                 }
             },
             onToggleFavourite: {
                 guard !mapModel.isResolvingAddress else { return }
                 guard let target = mapModel.selectedLocation else { return }
                 appModel.toggleFavourite(target)
             },
             onClearSelection: {
                 walkingSimulation.reset()
                 walkingRoutePlanner.clear()
                 mapModel.clearSelectedLocation()
             },
             onPreviewRoute: { mode in
                 guard !mapModel.isResolvingAddress else { return }
                 guard let target = mapModel.selectedLocation else { return }
                 Task {
                     if let route = await walkingRoutePlanner.preview(to: target, mode: mode) {
                         walkingSimulation.prepare(
                             route: route,
                             destination: target,
                             mode: mode,
                             coordinateMode: fixedCoordinateMode
                         )
                         mapModel.show(walkingRoutePlanner.routes)
                     }
                 }
             },
             onStart: {
                 guard !mapModel.isResolvingAddress else { return }
                 guard let target = mapModel.selectedLocation else { return }
                 shouldRefreshRealLocationWhenActive = false
                 mapModel.show(target)
                 Task {
                     await appModel.startLocationSession(
                         at: target,
                         coordinateMode: fixedCoordinateMode
                     )
                 }
             },
             onStop: {
                 shouldClearLocationAfterRestoration = true
                 appModel.stopLocationSession()
             }
         )
         }
    }

    @ViewBuilder
    private var sessionOverlays: some View {
        // Always present so the banner animates both in and out, whether it
        // is dismissed by a tap or by its timer.
        VStack {
            Spacer()
            if let message = mapModel.errorMessage {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                    .onTapGesture(perform: mapModel.dismissError)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Dismisses this message")
                    .padding(.bottom, 196)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 12)),
                                removal: .opacity.combined(with: .scale(scale: 0.92))
                            )
                    )
            }
        }
        .animation(
            reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.15),
            value: mapModel.errorMessage
        )

        if let guidance = appModel.deviceSession.mobileDataGuidance {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack {
                Spacer()
                MobileDataGuidanceView(
                    guidance: guidance,
                    tunnelHandoffApp: appModel.tunnelHandoffApp,
                    usesBuiltInTunnel: appModel.usesBuiltInTunnel,
                    isUsingMobileData: appModel.deviceSession.isUsingMobileDataForStartup,
                    onOpenTunnelApp: appModel.deviceSession.openSelectedTunnelApp,
                    onRetry: appModel.deviceSession.retryConnection,
                    onUseMobileData: appModel.deviceSession.useMobileDataGuidance,
                    onMobileDataOff: appModel.deviceSession.confirmMobileDataIsOff,
                    onCancel: appModel.stopLocationSession,
                    onDone: {
                        if appModel.isRestoringInterruptedSession {
                            appModel.completeInterruptedSessionRestorationAfterMobileData()
                        } else {
                            appModel.deviceSession.dismissMobileDataGuidance()
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            .zIndex(10)
        }

        if
            let recovery = appModel.interruptedSession,
            appModel.deviceSession.mobileDataGuidance == nil
        {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack {
                Spacer()
                SessionRecoveryView(
                    recovery: recovery,
                    isPaired: isPaired,
                    isResuming: isPreparingRecoveredWalk || appModel.isStartingLocationSession,
                    isRestoring: appModel.isRestoringInterruptedSession,
                    errorMessage: recoveredWalkError ?? appModel.interruptedSessionError,
                    onResume: {
                        resumeInterruptedSession(recovery)
                    },
                    onRestore: {
                        recoveredWalkError = nil
                        walkingSimulation.reset()
                        walkingRoutePlanner.clear()
                        Task { await appModel.restoreRealLocationFromInterruptedSession() }
                    },
                    onAlreadyRestored: {
                        dismissInterruptedSessionRecovery()
                    },
                    onCancel: {
                        if appModel.isRestoringInterruptedSession {
                            appModel.cancelInterruptedSessionRestoration()
                        } else if appModel.isStartingLocationSession {
                            appModel.stopLocationSession()
                        } else if isPreparingRecoveredWalk {
                            recoveredWalkPreparationIdentifier = nil
                            isPreparingRecoveredWalk = false
                            walkingRoutePlanner.clear()
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            .zIndex(9)
        }
    }

    private var needsPairingPrompt: Bool {
        switch appModel.pairingStatus {
        case .notPaired, .failed:
            true
        case .checking, .importing, .paired:
            false
        }
    }

    private var isSearchingForLocation: Bool {
        isSearchFocused || mapModel.isShowingSuggestions || mapModel.isShowingOverseasResults
    }

    private var isPaired: Bool {
        if case .paired = appModel.pairingStatus {
            return true
        }
        return false
    }

    private var shouldShowRealLocation: Bool {
        switch appModel.deviceSession.phase {
        case .active, .stopping:
            false
        case .idle, .openingLocalDevVPN, .discovering, .connecting, .failed:
            true
        }
    }

    private var canRequestRealLocation: Bool {
        switch appModel.deviceSession.phase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var isLocationSessionActive: Bool {
        if case .active = appModel.deviceSession.phase { return true }
        return false
    }

    private var normalisedMapHeading: Double {
        guard let heading = visibleMapCamera?.heading else { return 0 }
        let remainder = heading.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private var shouldShowMapCompass: Bool {
        let heading = normalisedMapHeading
        return min(heading, 360 - heading) > 1
    }

    private func resetMapHeading() {
        guard let camera = visibleMapCamera else { return }
        let northUpCamera = MapCamera(
            centerCoordinate: camera.centerCoordinate,
            distance: camera.distance,
            heading: 0,
            pitch: camera.pitch
        )

        if reduceMotion {
            mapModel.cameraPosition = .camera(northUpCamera)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapModel.cameraPosition = .camera(northUpCamera)
            }
        }
    }

    private func showCurrentLocationNorthUp() {
        if reduceMotion {
            mapModel.showCurrentLocation()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapModel.showCurrentLocation()
            }
        }
    }

    private func selectPreviewedRoute(_ index: Int) {
        guard
            !walkingSimulation.locksDestination,
            index != walkingRoutePlanner.selectedRouteIndex,
            let destination = walkingRoutePlanner.destination,
            let route = walkingRoutePlanner.selectRoute(at: index)
        else { return }

        walkingSimulation.prepare(
            route: route,
            destination: destination,
            mode: walkingRoutePlanner.mode,
            coordinateMode: walkingSimulation.coordinateMode
        )
    }

    /// Returns true when the tap landed on one of several previewed routes, so
    /// it chooses a route instead of dropping a pin and discarding the preview.
    private func selectPreviewedRoute(
        at point: CGPoint,
        coordinate: CLLocationCoordinate2D,
        proxy: MapProxy
    ) -> Bool {
        let routes = walkingRoutePlanner.routes
        guard routes.count > 1 else { return false }
        // Measure a finger-sized tolerance at the current zoom.
        guard let edge = proxy.convert(CGPoint(x: point.x + 22, y: point.y), from: .local) else {
            return false
        }

        let tap = MKMapPoint(coordinate)
        let edgePoint = MKMapPoint(edge)
        let tolerance = hypot(edgePoint.x - tap.x, edgePoint.y - tap.y)
        guard let index = RouteHitTesting.nearestRouteIndex(
            to: tap,
            in: routes.map(\.mapPoints),
            tolerance: tolerance
        ) else { return false }

        selectPreviewedRoute(index)
        return true
    }

    // Performs App Shortcuts requests with the same steps as the matching buttons.
    private func handleShortcutRequest() {
        guard let request = appModel.takeShortcutRequest() else { return }
        switch request.action {
        case .start(let target):
            isShowingSettings = false
            isShowingSavedPlaces = false
            shouldRefreshRealLocationWhenActive = false
            mapModel.show(target)
            Task {
                await appModel.startLocationSession(
                    at: target,
                    coordinateMode: appModel.coordinateMode(for: target)
                )
            }
        case .stop:
            shouldClearLocationAfterRestoration = true
            if walkingSimulation.locksDestination {
                walkingSimulation.stop(using: appModel.deviceSession)
            } else {
                appModel.stopLocationSession()
            }
        case .restoreInterruptedSession:
            recoveredWalkError = nil
            walkingSimulation.reset()
            walkingRoutePlanner.clear()
            Task { await appModel.restoreRealLocationFromInterruptedSession() }
        }
    }

    private func resumeInterruptedSession(_ recovery: SessionRecoveryRecord) {
        recoveredWalkError = nil

        guard recovery.isRoute, let destination = recovery.destination else {
            mapModel.show(recovery.lastReportedLocation)
            let mode = recovery.fixedCoordinateMode
                ?? FixedCoordinateMode.recommended(for: recovery.lastReportedLocation)
            fixedCoordinateMode = mode
            Task {
                await appModel.startLocationSession(
                    at: recovery.lastReportedLocation,
                    coordinateMode: mode
                )
            }
            return
        }

        let routeCoordinateMode = recovery.fixedCoordinateMode
            ?? FixedCoordinateMode.recommended(for: destination)
        fixedCoordinateMode = routeCoordinateMode
        isPreparingRecoveredWalk = true
        let preparationIdentifier = UUID()
        recoveredWalkPreparationIdentifier = preparationIdentifier
        Task { @MainActor in
            // A resumed route starts straight away, so there is nothing to choose between.
            let route = await walkingRoutePlanner.preview(
                to: destination,
                from: recovery.lastReportedLocation,
                mode: recovery.routeMode,
                includingAlternatives: false
            )
            guard recoveredWalkPreparationIdentifier == preparationIdentifier else { return }
            recoveredWalkPreparationIdentifier = nil
            guard let route else {
                recoveredWalkError = walkingRoutePlanner.errorMessage
                    ?? String(localized: "The remaining route could not be prepared.")
                isPreparingRecoveredWalk = false
                return
            }

            walkingSimulation.prepare(
                route: route,
                destination: destination,
                mode: recovery.routeMode,
                coordinateMode: routeCoordinateMode
            )
            if let savedSpeed = recovery.savedRouteSpeed, savedSpeed.isFinite {
                if recovery.routeMode == .walking {
                    if let recoveredPace = WalkingPace.allCases.first(where: {
                        abs($0.metresPerSecond - savedSpeed) < 0.0001
                    }) {
                        walkingSimulation.pace = recoveredPace
                        walkingSimulation.customWalkingSpeedKilometresPerHour = nil
                    } else {
                        walkingSimulation.customWalkingSpeedKilometresPerHour = min(max(savedSpeed * 3.6, 1), 12)
                    }
                } else if recovery.routeMode == .driving {
                    walkingSimulation.drivingSpeedKilometresPerHour = min(max(savedSpeed * 3.6, 5), 240)
                }
            }
            mapModel.show(route)
            followsSimulatedLocation = recovery.routeMode == .driving
            isPreparingRecoveredWalk = false
            await walkingSimulation.start(using: appModel)
        }
    }

    private func dismissInterruptedSessionRecovery() {
        recoveredWalkError = nil
        isPreparingRecoveredWalk = false
        recoveredWalkPreparationIdentifier = nil
        walkingSimulation.reset()
        walkingRoutePlanner.clear()
        appModel.dismissInterruptedSessionRecovery()
        mapModel.showRealLocationAfterSession()
    }
}

private struct CompassRoseDial: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.primary.opacity(0.06))

            Circle()
                .strokeBorder(.primary.opacity(0.28), lineWidth: 0.8)

            Text("N")
                .foregroundStyle(.red)
                .offset(y: -10.5)

            Text("E")
                .offset(x: 10.5)

            Text("S")
                .offset(y: 10.5)

            Text("W")
                .offset(x: -10.5)

            Circle()
                .fill(.primary.opacity(0.65))
                .frame(width: 3, height: 3)
        }
        .font(.system(size: 7.5, weight: .bold, design: .rounded))
        .foregroundStyle(.primary.opacity(0.78))
        .frame(width: 34, height: 34)
    }
}

private extension View {
    @ViewBuilder
    func roamControlMapStyle(_ style: MapDisplayStyle) -> some View {
        switch style {
        case .standard:
            mapStyle(.standard(elevation: .realistic))
        case .satellite:
            mapStyle(.imagery(elevation: .realistic))
        case .hybrid:
            mapStyle(.hybrid(elevation: .realistic))
        }
    }
}

#Preview {
    HomeView()
        .environment(AppModel())
        .environment(ReleaseUpdateModel())
}
