import MapKit
import SwiftUI
import UIKit

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
    @State private var customRouteDraft: CustomRouteDraft?
    @State private var customRouteWaypoints: [RouteWaypoint]?
    @State private var shouldRefreshRealLocationWhenActive = false
    @State private var shouldClearLocationAfterRestoration = false
    @State private var isLocatingRealLocationAfterRestoration = false
    @State private var visibleMapCamera: MapCamera?
    @State private var isPreciselyPicking = false
    @State private var isPreparingRecoveredWalk = false
    @State private var recoveredWalkPreparationIdentifier: UUID?
    @State private var recoveredWalkError: String?
    @State private var followsSimulatedLocation = false
    @State private var fixedCoordinateMode: FixedCoordinateMode = .wgs84
    @State private var compactHeaderHeight: CGFloat = 0
    private enum DockPosition: Int { case collapsed, medium, expanded }
    @State private var dockPosition: DockPosition = .medium
    @State private var dockDrag: CGFloat = 0
    @GestureState private var isDockDragging = false
    @State private var expandedDockContentHeight: CGFloat = 280
    @State private var compactDockContentHeight: CGFloat = 176
    @State private var dockMapControlsHeight: CGFloat = 0
    @State private var dockWarningHeight: CGFloat = 0
    @State private var bottomDockHeight: CGFloat = 0
    @FocusState private var isSearchFocused: Bool
    @AppStorage("isMapPanelDetailsCollapsed") private var areDetailsCollapsed =
        UIDevice.current.userInterfaceIdiom == .pad
        || UserDefaults.standard.bool(forKey: "isLocationCardCollapsed")
    @AppStorage("isMapSidebarCollapsed") private var isSidebarCollapsed = false

    init(
        showDeviceSetupInitially: Bool = false,
        showSettingsInitially: Bool = false
    ) {
        _isShowingDeviceSetup = State(initialValue: showDeviceSetupInitially)
        _isShowingSettings = State(initialValue: showSettingsInitially)
    }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width >= 900 && geometry.size.width > geometry.size.height
            let sidebarWidth = min(400, max(360, geometry.size.width * 0.3))
            let showsDock =
                !isPreciselyPicking
                && (isWide
                    ? isSidebarCollapsed && hasSelectedSessionContent : !isSearchingForLocation)
            ZStack {
                if isWide {
                    HStack(spacing: 0) {
                        if !isSidebarCollapsed {
                            sidebar
                                .frame(width: sidebarWidth)
                                .disabled(isPreciselyPicking)
                                .transition(
                                    reduceMotion
                                        ? .opacity : .move(edge: .leading).combined(with: .opacity))
                        }
                        mapContent
                            .overlay(alignment: .topLeading) {
                                if isSidebarCollapsed && !isPreciselyPicking {
                                    showSidebarButton
                                        .padding(16)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if !showsDock && !isPreciselyPicking {
                                    mapControls.padding(16)
                                }
                            }
                    }
                    if showsDock {
                        bottomDock(
                            availableHeight: geometry.size.height,
                            detailsCollapsed: hiddenSidebarDisclosure)
                    }
                } else {
                    mapContent
                    if !isPreciselyPicking {
                        compactControls(availableHeight: geometry.size.height)
                    }
                }
                sessionOverlays(
                    reservedBottomSpace: showsDock ? bottomDockHeight : 0,
                    leadingInset: isWide && !isSidebarCollapsed ? sidebarWidth : 0
                )
            }
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.9),
                value: isSidebarCollapsed)
        }
        .task {
            await appModel.restorePairingStatus()
            if let interruptedLocation = appModel.interruptedSession?.lastReportedLocation {
                mapModel.center(on: interruptedLocation)
            }
            mapModel.prepareCurrentLocation(
                recenter: appModel.interruptedSession == nil && !isPreciselyPicking
            )
            if isShowingDeviceSetup {
                appModel.deviceSetupWasPresented()
            }
        }
        .onChange(of: appModel.shortcutRequest?.id, initial: true) {
            handleShortcutRequest()
        }
        .onChange(of: canPickPrecisely) { _, canPick in
            if !canPick { isPreciselyPicking = false }
        }
        .onChange(of: appModel.deviceSession.phase) { oldPhase, newPhase in
            walkingSimulation.handleDeviceSessionPhase(
                newPhase,
                deviceSession: appModel.deviceSession,
                appModel: appModel
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
                let coordinate = walkingSimulation.currentCoordinate
            else { return }
            mapModel.center(on: coordinate)
        }
        .onChange(of: hasSelectedSessionContent, initial: true) { _, hasContent in
            if !hasContent { setDockPosition(.collapsed) }
            else if dockPosition == .collapsed { setDockPosition(.medium) }
        }
        .onChange(of: mapModel.selectedLocation?.id) { _, selectedLocationID in
            if walkingRoutePlanner.route?.isCustom == true,
               walkingRoutePlanner.destination?.id == selectedLocationID {
                fixedCoordinateMode = walkingSimulation.coordinateMode
                return
            }
            if let selectedLocation = mapModel.selectedLocation {
                if case .active(let activeTarget) = appModel.deviceSession.phase,
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
            guard newPhase == .active else {
                isPreciselyPicking = false
                return
            }
            appModel.deviceSession.appDidBecomeActive()

            guard shouldRefreshRealLocationWhenActive else { return }
            shouldRefreshRealLocationWhenActive = false
            guard case .idle = appModel.deviceSession.phase else { return }
            mapModel.showRealLocationAfterSession()
        }
        .fullScreenCover(item: $customRouteDraft) { draft in
            CustomRouteEditor(draft: draft, locationModel: mapModel) { waypoints, coordinateMode, speed in
                let route = try walkingRoutePlanner.previewCustomRoute(
                    coordinates: waypoints.map(\.coordinate), name: waypoints.last?.name ?? String(localized: "Custom route"))
                customRouteWaypoints = waypoints
                guard let destination = walkingRoutePlanner.destination else { return }
                mapModel.show(destination)
                fixedCoordinateMode = coordinateMode
                walkingSimulation.prepare(route: route, destination: destination,
                                          coordinateMode: coordinateMode, startName: waypoints.first?.name)
                walkingSimulation.customRouteSpeedKilometresPerHour = speed
                mapModel.show(route)
            }
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
                        guard let refreshed = await mapModel.refreshAddressIfNeeded(for: target)
                        else {
                            return
                        }
                        appModel.updateStoredLocationMetadata(with: refreshed)
                    }
                },
                onToggleFavourite: appModel.toggleFavourite,
                onDeleteFavourite: appModel.removeFavourite,
                onMoveFavourites: appModel.moveFavouriteLocations,
                onDismissFavouriteReorderHint: appModel.dismissFavouriteReorderHint,
                onRenameFavourite: { target, name in
                    if let renamed = appModel.renameFavourite(target, to: name),
                       let selected = mapModel.selectedLocation, selected.id == renamed.id {
                        mapModel.selectedLocation = selected.renamed(to: renamed.name)
                    }
                },
                onDeleteHistory: appModel.removeFromHistory,
                onClearFavourites: appModel.clearFavouriteLocations,
                onClearHistory: appModel.clearLocationHistory
            )
        }
    }

    // Use the available window shape so rotation and iPad window resizing use
    // the same layout rules. Session state stays in the shared models above.
    private var mapContent: some View {
        MapReader { proxy in
            let fixedTarget = activeFixedTarget
            Map(position: $mapModel.cameraPosition,
                interactionModes: isPreciselyPicking ? [.pan, .zoom, .rotate] : .all) {
                // Draw the alternatives first so the selected route stays on top.
                ForEach(
                    Array(walkingRoutePlanner.routes.enumerated()),
                    id: \.offset
                ) { index, alternative in
                    if index != walkingRoutePlanner.selectedRouteIndex {
                        MapPolyline(alternative.polyline)
                            .stroke(.blue.opacity(0.35), lineWidth: 5)
                    }
                }

                if let route = walkingRoutePlanner.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }

                if shouldShowRealLocation {
                    UserAnnotation()
                }

                if let target = mapModel.selectedLocation, target.id != fixedTarget?.id {
                    Marker(target.name, coordinate: target.coordinate)
                        .tint(.blue)
                }

                if let fixedTarget {
                    Annotation(String(localized: "Current simulated target"), coordinate: fixedTarget.coordinate) {
                        simulatedLocationGlyph("location.circle.fill")
                    }
                }

                if let coordinate = walkingSimulation.currentCoordinate {
                    Annotation(String(localized: "Simulated route location"), coordinate: coordinate) {
                        simulatedLocationGlyph(
                            walkingRoutePlanner.route?.isCustom == true ? "location.circle.fill" : walkingSimulation.mode == .walking
                                ? "figure.walk.circle.fill" : "car.circle.fill"
                        )
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

                guard !isPreciselyPicking, !walkingSimulation.locksDestination else { return }
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                if selectPreviewedRoute(at: point, coordinate: coordinate, proxy: proxy) { return }
                Task { await mapModel.selectDroppedPin(at: coordinate) }
            }
            .ignoresSafeArea()
            .overlay {
                if isPreciselyPicking {
                    PrecisionMapPicker(
                        camera: visibleMapCamera,
                        coordinateAtPoint: { proxy.convert($0, from: .named(PrecisionMapPicker.mapSpace)) },
                        onMove: { movePrecisionCamera(by: $0, with: proxy) },
                        onConfirm: confirmPrecisionSelection,
                        onCancel: { isPreciselyPicking = false }
                    )
                }
            }
        }
        .coordinateSpace(name: PrecisionMapPicker.mapSpace)
    }

    private func simulatedLocationGlyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.title.weight(.semibold))
            .foregroundStyle(.white, .green)
            .padding(4)
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Map Controls")
                    .font(.headline)
                Spacer(minLength: 8)
                Button(action: hideSidebar) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide Controls")
                .accessibilityIdentifier("map.hideSidebar")
            }
            .padding(.horizontal, 16)
            .simultaneousGesture(
                DragGesture(minimumDistance: 25).onEnded { value in
                    if value.translation.width < -60,
                        abs(value.translation.width) > abs(value.translation.height) * 1.4
                    {
                        hideSidebar()
                    }
                }
            )

            ScrollView {
                VStack(spacing: 12) {
                    searchPanel
                    if !isSearchingForLocation {
                        statusPanel
                        backgroundWarning
                        selectionCard(detailsCollapsed: $areDetailsCollapsed)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var showSidebarButton: some View {
        Button {
            isSidebarCollapsed = false
        } label: {
            Label("Show Controls", systemImage: "sidebar.leading")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.showSidebar")
    }

    private func hideSidebar() {
        isSearchFocused = false
        isSidebarCollapsed = true
    }

    private var hiddenSidebarDisclosure: Binding<Bool> {
        Binding(
            get: { true },
            set: { collapsed in
                if !collapsed {
                    mapModel.clearSearch()
                    areDetailsCollapsed = false
                    isSidebarCollapsed = false
                }
            }
        )
    }

    private var hasSelectedSessionContent: Bool {
        mapModel.selectedLocation != nil || walkingRoutePlanner.route != nil
            || isLocatingRealLocationAfterRestoration
    }

    private func compactControls(availableHeight: CGFloat) -> some View {
        ZStack(alignment: .top) {
            MapPanelViewport(maximumHeight: max(160, availableHeight * 0.42)) {
                VStack(spacing: 10) {
                    searchPanel
                    if !isSearchingForLocation {
                        statusPanel
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                compactHeaderHeight = height
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if !isSearchingForLocation {
                bottomDock(
                    availableHeight: availableHeight,
                    detailsCollapsed: $areDetailsCollapsed,
                    topClearance: compactHeaderHeight + 8
                )
            }
        }
    }

    private func bottomDock(
        availableHeight: CGFloat,
        detailsCollapsed: Binding<Bool>,
        topClearance: CGFloat = 60
    ) -> some View {
        let maximum = max(200, availableHeight - 8)
        let pinsLocationHeader = availableHeight >= 420 && mapModel.selectedLocation != nil
            && !isLocatingRealLocationAfterRestoration && walkingRoutePlanner.route == nil
        let mediumLimit = pinsLocationHeader
            ? max(availableHeight * 0.48, availableHeight - topClearance - dockMapControlsHeight - 18)
            : availableHeight * 0.48
        let warningSpace = pinsLocationHeader && showsBackgroundWarning ? dockWarningHeight + 10 : 0
        let compact = min(maximum, max(180, compactDockContentHeight + warningSpace + 44))
        let expandedContent = expandedDockContentHeight + warningSpace + 44
        let medium = min(maximum, max(compact, min(mediumLimit, expandedContent)))
        let full = min(maximum, max(medium + 32, expandedContent))
        let heights: [CGFloat] = [compact, medium, full]
        let height = min(maximum, max(heights[0], heights[dockPosition.rawValue] - dockDrag))
        let collapsed = Binding(
            get: { dockPosition == .collapsed },
            set: { value in setDockPosition(value ? .collapsed : .medium) })
        return VStack(spacing: 10) {
            if !hasSelectedSessionContent || dockPosition != .expanded {
                mapControls.padding(.horizontal, 16)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { dockMapControlsHeight = $0 }
            }
            if hasSelectedSessionContent {
                VStack(spacing: 0) {
                    Capsule().fill(.secondary.opacity(0.4)).frame(width: 36, height: 5)
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                            .updating($isDockDragging) { _, state, _ in state = true }
                            .onChanged { value in
                                if abs(value.translation.height) > abs(value.translation.width) { dockDrag = value.translation.height }
                            }
                            .onEnded { value in
                                guard abs(value.translation.height) > 36,
                                      abs(value.translation.height) > abs(value.translation.width) else { dockDrag = 0; return }
                                let next = min(2, max(0, dockPosition.rawValue + (value.translation.height < 0 ? 1 : -1)))
                                setDockPosition(DockPosition(rawValue: next) ?? .medium)
                            })
                        .accessibilityElement()
                        .accessibilityLabel("Route panel handle")
                        .accessibilityValue(dockPosition == .expanded ? String(localized: "Full panel") : dockPosition == .medium ? String(localized: "Half panel") : String(localized: "Compact panel"))
                        .accessibilityIdentifier("map.panelHandle")
                        .accessibilityAction(named: Text("Expand route panel")) { setDockPosition(.expanded) }
                        .accessibilityAction(named: Text("Collapse route panel")) { setDockPosition(.collapsed) }
                    if pinsLocationHeader {
                        VStack(spacing: 10) {
                            if showsBackgroundWarning {
                                backgroundWarning
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { dockWarningHeight = $0 }
                            }
                            selectionCard(detailsCollapsed: collapsed, onDockContentHeightChanged: recordDockContentHeight)
                        }
                        .environment(\.isEmbeddedMapPanel, true)
                        .transaction { $0.animation = nil }
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                backgroundWarning
                                selectionCard(detailsCollapsed: collapsed)
                            }
                            .environment(\.isEmbeddedMapPanel, true)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { recordDockContentHeight($0) }
                            .transaction { $0.animation = nil }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .accessibilityIdentifier("map.bottomCard")
                    }
                }
                .frame(height: height, alignment: .top)
                .animation(reduceMotion || isDockDragging ? nil : .easeInOut(duration: 0.22), value: height)
                .onChange(of: isDockDragging) { _, dragging in if !dragging { dockDrag = 0 } }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: dockPosition == .expanded ? 0 : 32,
                    bottomTrailingRadius: dockPosition == .expanded ? 0 : 32, topTrailingRadius: 32))
                .background { MapFloatingPanelBackground(isExpanded: dockPosition == .expanded) }
            } else {
                Button { isSearchFocused = true } label: {
                    selectionCard(detailsCollapsed: .constant(true))
                        .environment(\.isEmbeddedMapPanel, true)
                }
                .buttonStyle(.plain)
                .background { MapFloatingPanelBackground(isExpanded: false) }
                .accessibilityIdentifier("map.emptyPrompt")
                .accessibilityHint("Opens place search")
            }

        }
        .padding(.horizontal, hasSelectedSessionContent && dockPosition == .expanded ? 0 : 12)
        .padding(.bottom, hasSelectedSessionContent && dockPosition == .expanded ? 0 : 8)
        .frame(maxWidth: 600)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomDockHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func recordDockContentHeight(_ height: CGFloat) {
        if dockPosition == .collapsed { compactDockContentHeight = height }
        else { expandedDockContentHeight = height }
    }

    private func setDockPosition(_ position: DockPosition) {
        dockDrag = 0
        dockPosition = position
        areDetailsCollapsed = position == .collapsed
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
                        isSearchFocused = false
                        customRouteDraft = CustomRouteDraft(start: mapModel.selectedLocation,
                                                            camera: visibleMapCamera.map { .camera($0) } ?? mapModel.cameraPosition,
                                                            coordinateMode: fixedCoordinateMode)
                    } label: {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRequestRealLocation || walkingSimulation.locksDestination)
                    .accessibilityLabel("Custom route")
                    .accessibilityIdentifier("map.customRoute")

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
                                Text(
                                    String(
                                        format: NSLocalizedString(
                                            "WrapPin %@ is available.", comment: ""),
                                        release.version
                                    )
                                )
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
                .background(
                    .regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
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
                    .background(
                        .regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var showsBackgroundWarning: Bool {
        guard case .active = appModel.deviceSession.phase else { return false }
        return !appModel.deviceSession.backgroundKeepAlive.started
            && appModel.deviceSession.backgroundKeepAlive.status != .awaitingAuthorization
    }

    @ViewBuilder
    private var backgroundWarning: some View {
        if showsBackgroundWarning {
            Label(
                "The current simulation can still work in the foreground, but background continuity is unavailable. Check Location access for WrapPin in Settings.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .background(
                .regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private var mapControls: some View {
        HStack {
            Spacer()

            VStack(spacing: 10) {
                if canPickPrecisely {
                    mapControl("Precision selection", symbol: "scope", action: beginPrecisionSelection)
                        .disabled(visibleMapCamera == nil)
                        .accessibilityIdentifier("map.beginPrecisionSelection")
                }

                if let target = activeFixedTarget {
                    mapControl("Show simulated target", symbol: "location.circle.fill") {
                        mapModel.center(on: target)
                    }
                }

                if walkingSimulation.mode == .driving,
                    let coordinate = walkingSimulation.currentCoordinate,
                    let route = walkingRoutePlanner.route
                {
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
                    .accessibilityLabel(
                        followsSimulatedLocation
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
                                    .font(
                                        .system(
                                            size: min(mapControlSymbolSize, 24), weight: .semibold)
                                    )
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

    private func mapControl(
        _ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: min(mapControlSymbolSize, 24), weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func selectionCard(
        detailsCollapsed: Binding<Bool>,
        onDockContentHeightChanged: ((CGFloat) -> Void)? = nil
    ) -> some View {
        if isLocatingRealLocationAfterRestoration {
            RestoringRealLocationCard()
        } else if let route = walkingRoutePlanner.route,
            let destination = walkingRoutePlanner.destination
        {
            WalkingRoutePreviewCard(
                route: route,
                routes: walkingRoutePlanner.routes,
                selectedRouteIndex: walkingRoutePlanner.selectedRouteIndex,
                destination: walkingSimulation.destination ?? destination,
                simulation: walkingSimulation,
                isPaired: isPaired,
                isCollapsed: detailsCollapsed,
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
                    customRouteWaypoints?.reverse()
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
                },
                onEditCustomRoute: {
                    customRouteDraft = CustomRouteDraft(
                        start: nil, camera: mapModel.cameraPosition,
                        coordinates: route.mapPoints.map(\.coordinate),
                        coordinateMode: walkingSimulation.coordinateMode,
                        waypoints: customRouteWaypoints,
                        speed: walkingSimulation.customRouteSpeedKilometresPerHour)
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
                isCollapsed: detailsCollapsed,
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
                    mapModel.clearSelectedLocation(revertingTo: activeFixedTarget)
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
                },
                onDockContentHeightChanged: onDockContentHeightChanged
            )
        }
    }

    @ViewBuilder
    private func sessionOverlays(reservedBottomSpace: CGFloat, leadingInset: CGFloat) -> some View {
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
                    .padding(.bottom, reservedBottomSpace + 12)
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
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, leadingInset)
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

        if let recovery = appModel.interruptedSession,
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
        guard !appModel.deviceSession.isReconnecting, appModel.interruptedSession == nil,
            !appModel.isRestoringInterruptedSession, !isLocatingRealLocationAfterRestoration
        else { return false }
        return switch appModel.deviceSession.phase {
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

    private var activeFixedTarget: LocationTarget? {
        guard !appModel.isRestoringInterruptedSession,
            !appModel.isRunningRouteSession,
            walkingSimulation.currentCoordinate == nil,
            case .active(let target) = appModel.deviceSession.phase
        else { return nil }
        return target
    }

    private var canPickPrecisely: Bool {
        !isSearchingForLocation && !mapModel.isSearching && !walkingSimulation.locksDestination
            && !walkingRoutePlanner.isLoading && !appModel.isRunningRouteSession
            && !appModel.deviceSession.isBusy && appModel.deviceSession.mobileDataGuidance == nil
            && !appModel.isStartingLocationSession && appModel.interruptedSession == nil
            && !appModel.isRestoringInterruptedSession && !isLocatingRealLocationAfterRestoration
    }

    private func beginPrecisionSelection() {
        guard canPickPrecisely, let camera = visibleMapCamera else { return }
        shouldRefreshRealLocationWhenActive = false
        mapModel.clearSearch()
        mapModel.stopRecenteringOnRealLocation()
        mapModel.cameraPosition = .camera(MapCamera(
            centerCoordinate: camera.centerCoordinate,
            distance: camera.distance,
            heading: camera.heading
        ))
        isPreciselyPicking = true
    }

    private func confirmPrecisionSelection(at coordinate: CLLocationCoordinate2D) {
        guard canPickPrecisely, isPreciselyPicking else { return }
        isPreciselyPicking = false
        Task { await mapModel.selectDroppedPin(at: coordinate) }
    }

    private func movePrecisionCamera(by offset: CGSize, with proxy: MapProxy) {
        let space = NamedCoordinateSpace.named(PrecisionMapPicker.mapSpace)
        guard isPreciselyPicking, let camera = visibleMapCamera,
            let center = proxy.convert(camera.centerCoordinate, to: space),
            let coordinate = proxy.convert(
                CGPoint(x: center.x + offset.width, y: center.y + offset.height), from: space
            ),
            CLLocationCoordinate2DIsValid(coordinate)
        else { return }
        mapModel.cameraPosition = .camera(MapCamera(
            centerCoordinate: coordinate,
            distance: camera.distance,
            heading: camera.heading
        ))
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
        guard
            let index = RouteHitTesting.nearestRouteIndex(
                to: tap,
                in: routes.map(\.mapPoints),
                tolerance: tolerance
            )
        else { return false }

        selectPreviewedRoute(index)
        return true
    }

    // Performs App Shortcuts requests with the same steps as the matching buttons.
    private func handleShortcutRequest() {
        guard let request = appModel.takeShortcutRequest() else { return }
        isPreciselyPicking = false
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
        customRouteWaypoints = nil

        guard recovery.isRoute, let destination = recovery.destination else {
            mapModel.show(recovery.lastReportedLocation)
            let mode =
                recovery.fixedCoordinateMode
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

        let routeCoordinateMode =
            recovery.fixedCoordinateMode
            ?? FixedCoordinateMode.recommended(for: destination)
        fixedCoordinateMode = routeCoordinateMode
        isPreparingRecoveredWalk = true
        let preparationIdentifier = UUID()
        recoveredWalkPreparationIdentifier = preparationIdentifier
        Task { @MainActor in
            // A resumed route starts straight away, so there is nothing to choose between.
            let route: SimulationRoute?
            if let savedPoints = recovery.customRoutePoints {
                let next = recovery.nextCustomRoutePointIndex ?? 1
                if next >= 1, next < savedPoints.count, savedPoints.count <= GPXRouteParser.maximumPointCount {
                    let remaining = [recovery.lastReportedLocation.coordinate] + savedPoints.dropFirst(next).map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    }
                    route = try? walkingRoutePlanner.previewCustomRoute(
                        coordinates: remaining, name: destination.name, mode: recovery.routeMode)
                } else {
                    route = nil
                }
            } else {
                route = await walkingRoutePlanner.preview(
                    to: destination, from: recovery.lastReportedLocation,
                    mode: recovery.routeMode, includingAlternatives: false)
            }
            guard recoveredWalkPreparationIdentifier == preparationIdentifier else { return }
            recoveredWalkPreparationIdentifier = nil
            guard let route else {
                recoveredWalkError =
                    walkingRoutePlanner.errorMessage
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
                if route.isCustom {
                    walkingSimulation.customRouteSpeedKilometresPerHour = savedSpeed * 3.6
                } else if recovery.routeMode == .walking {
                    if let recoveredPace = WalkingPace.allCases.first(where: {
                        abs($0.metresPerSecond - savedSpeed) < 0.0001
                    }) {
                        walkingSimulation.pace = recoveredPace
                        walkingSimulation.customWalkingSpeedKilometresPerHour = nil
                    } else {
                        walkingSimulation.customWalkingSpeedKilometresPerHour = min(
                            max(savedSpeed * 3.6, 1), 12)
                    }
                } else if recovery.routeMode == .driving {
                    walkingSimulation.drivingSpeedKilometresPerHour = min(
                        max(savedSpeed * 3.6, 5), 240)
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

extension View {
    @ViewBuilder
    fileprivate func roamControlMapStyle(_ style: MapDisplayStyle) -> some View {
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
