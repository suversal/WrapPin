import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct CustomRouteDraft: Identifiable {
    let id = UUID()
    let start: LocationTarget?
    let camera: MapCameraPosition
    var coordinates: [CLLocationCoordinate2D]? = nil
    var coordinateMode: FixedCoordinateMode = .wgs84
    var waypoints: [RouteWaypoint]? = nil
    var speed: Double = 5
}

struct CustomRouteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var points: [RouteWaypoint]
    @State private var coordinateMode: FixedCoordinateMode
    @State private var camera: MapCameraPosition
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?
    @State private var isReadingFile = false
    @State private var segments: [GPXRouteSegment] = []
    @State private var isChoosingSegment = false
    @State private var placePicker: RoutePlacePickerRequest?
    @State private var visibleRegion: MKCoordinateRegion?
    private enum Confirmation: Equatable { case discardChanges, clearRoute, failure(String) }
    @State private var confirmation: Confirmation?
    @State private var undoStates: [RouteEditSnapshot] = []
    @State private var previewRoute: SimulationRoute?
    private enum PanelStop: Int { case collapsed, medium, expanded }
    @State private var panelStop: PanelStop = .medium
    @State private var panelDrag: CGFloat = 0
    @GestureState private var isPanelDragging = false
    @State private var locationModel: MapViewModel
    @State private var isWaitingForCurrentLocation = false
    @State private var reportsLocationErrors = false
    @State private var isPickingOnMap = false
    @State private var mapCandidate: CLLocationCoordinate2D?
    @State private var mapSelectionReturnStop: PanelStop = .medium
    @State private var speed: Double
    @State private var isShowingOptions = false
    @State private var mapSize: CGSize = .zero
    private let initialPoints: [RouteWaypoint]
    private let initialSpeed: Double
    private let initialCoordinateMode: FixedCoordinateMode
    let onPreview: ([RouteWaypoint], FixedCoordinateMode, Double) throws -> Void

    init(draft: CustomRouteDraft, locationModel: MapViewModel? = nil, onPreview: @escaping ([RouteWaypoint], FixedCoordinateMode, Double) throws -> Void) {
        let initialPoints = draft.waypoints ?? draft.coordinates.map { coordinates in
            coordinates.map { RouteWaypoint(coordinate: $0) }
        } ?? draft.start.map { [RouteWaypoint(target: $0)] } ?? []
        self.initialPoints = initialPoints
        initialSpeed = draft.speed
        initialCoordinateMode = draft.coordinateMode
        _points = State(initialValue: initialPoints)
        _previewRoute = State(initialValue: try? SimulationRoute(
            coordinates: initialPoints.map(\.coordinate), name: ""))
        _coordinateMode = State(initialValue: draft.coordinateMode)
        let model = locationModel ?? MapViewModel(selectsFirstSearchResult: false, enablesSearchSuggestions: false)
        _locationModel = State(initialValue: model)
        if initialPoints.isEmpty, let coordinate = model.currentRealCoordinate {
            _camera = State(initialValue: .region(MKCoordinateRegion(center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025))))
        } else {
            _camera = State(initialValue: draft.camera)
        }
        _speed = State(initialValue: draft.speed)
        self.onPreview = onPreview
    }

    private var coordinates: [CLLocationCoordinate2D] { points.map(\.coordinate) }
    private var route: SimulationRoute? { previewRoute }
    private var hasChanges: Bool { points != initialPoints || coordinateMode != initialCoordinateMode || speed != initialSpeed }

    var body: some View {
        GeometryReader { geometry in
            let heights = panelHeights(for: geometry)
            let height = min(heights[2], max(heights[0], heights[panelStop.rawValue] - panelDrag))
            ZStack(alignment: .bottom) {
                routeMap.ignoresSafeArea()
                VStack {
                    HStack {
                        Button {
                            if hasChanges { confirmation = .discardChanges }
                            else { dismiss() }
                        } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .background(.regularMaterial, in: Circle())
                        .accessibilityLabel("Cancel")
                        .accessibilityIdentifier("customRoute.cancel")
                        Spacer()
                        Text("Custom route").font(.headline)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(.regularMaterial, in: Capsule())
                        Spacer()
                        Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 16).padding(.top, 8)
                    Spacer()
                }
                VStack(spacing: 0) {
                    panelHandle(heights: heights)
                    if isPickingOnMap { mapSelectionContent }
                    else if panelStop == .collapsed {
                        HStack {
                            Text("Route points").font(.headline)
                            Spacer()
                            Text("\(points.count)").foregroundStyle(.secondary)
                            Button("Edit route") { setPanel(.medium) }
                        }.padding(.horizontal, 20)
                        Spacer(minLength: 0)
                    } else {
                        HStack {
                            Text(panelStop == .expanded ? "Edit route" : "Route points").font(.headline)
                            Text("\(points.count)").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            if panelStop == .expanded {
                                Button("Clear all route points", role: .destructive) { confirmation = .clearRoute }
                                    .font(.subheadline).frame(minHeight: 44)
                                    .disabled(points.isEmpty || isReadingFile)
                                    .accessibilityIdentifier("customRoute.clearAll")
                            } else if let route {
                                Text(route.distance.formatted(.number.precision(.fractionLength(1))) + " m")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .padding(.horizontal, 20).padding(.bottom, 2)
                        List {
                            waypointList
                            if panelStop == .expanded {
                                Section {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Label("Simulation speed", systemImage: "speedometer")
                                            Spacer(minLength: 8)
                                            Text("\(speed, specifier: "%.1f") km/h").monospacedDigit()
                                        }.font(.subheadline)
                                        Slider(value: $speed, in: 0.1...240, step: 0.1)
                                            .accessibilityLabel("Simulation speed")
                                            .accessibilityIdentifier("customRoute.speed")
                                            .accessibilityValue(String(format: "%.1f", speed))
                                    }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                    editorControls
                                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                                } footer: {
                                    Text("Points connect with straight lines in order. Hold the right handle to reorder.")
                                        .font(.caption)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .contentMargins(.vertical, 0, for: .scrollContent)
                        .listSectionSpacing(4)
                        .environment(\.editMode, .constant(.active))
                        .accessibilityIdentifier("customRoute.scroll")
                        HStack(spacing: 12) {
                            addButton.frame(maxWidth: .infinity)
                            Button(action: beginMapSelection) {
                                Label("Pick on map", systemImage: "mappin.and.ellipse")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                        .buttonStyle(.plain).foregroundStyle(.tint)
                        .font(.subheadline.weight(.medium))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .padding(.horizontal, 20)


                    }
                    if !isPickingOnMap { previewAction }
                }
                .frame(height: height, alignment: .top)
                .animation(reduceMotion || isPanelDragging ? nil : .easeInOut(duration: 0.22), value: height)
                .onChange(of: isPanelDragging) { _, dragging in if !dragging { panelDrag = 0 } }
                .frame(maxWidth: 600)
                .background { MapFloatingPanelBackground(isExpanded: panelStop == .expanded) }
                .overlay(alignment: .topTrailing) {
                    if panelStop != .expanded {
                    VStack(spacing: 10) {
                        Button(action: fitRoute) { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44) }
                            .accessibilityLabel("Show whole route")
                            .accessibilityIdentifier("customRoute.overview")
                            .disabled(points.isEmpty)
                        Button { requestCurrentPosition(reportErrors: true) } label: {
                            Group {
                                if isWaitingForCurrentLocation { ProgressView().controlSize(.small) }
                                else { Image(systemName: "location.fill") }
                            }.frame(width: 44, height: 44)
                        }
                        .foregroundStyle(.blue)
                        .disabled(isWaitingForCurrentLocation)
                        .accessibilityLabel("Show my current location")
                        .accessibilityIdentifier("customRoute.currentLocation")
                    }
                    .buttonStyle(.plain).font(.system(size: 17, weight: .semibold))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .offset(y: -114).padding(.trailing, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                mapSize = geometry.size
                if points.isEmpty { requestCurrentPosition(reportErrors: false) }
                else { fitRoute() }
            }
            .onChange(of: locationModel.realLocationRevision) { _, _ in
                if isWaitingForCurrentLocation { applyCurrentPositionIfAvailable() }
            }
            .onChange(of: locationModel.isFindingRealLocation) { _, finding in
                if !finding && isWaitingForCurrentLocation {
                    applyCurrentPositionIfAvailable()
                    isWaitingForCurrentLocation = false
                    if reportsLocationErrors, let message = locationModel.errorMessage { showError(message) }
                }
            }
            .onChange(of: geometry.size) { _, size in mapSize = size }
            .interactiveDismissDisabled(hasChanges || isReadingFile)
            .onChange(of: points) { _, _ in
                // Rebuild the polyline only when edits change points, never on map pans.
                previewRoute = try? SimulationRoute(coordinates: coordinates, name: "")
            }
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml],
                          allowsMultipleSelection: false, onCompletion: importFile)
            .sheet(isPresented: $isChoosingSegment) {
                NavigationStack {
                    List(segments) { segment in
                        Button {
                            use(segment)
                            isChoosingSegment = false
                        } label: {
                            Text(String(format: NSLocalizedString("Segment %lld · %lld points", comment: ""), segment.id + 1, segment.coordinates.count))
                        }
                        .frame(minHeight: 44)
                    }
                    .navigationTitle("Choose GPX segment")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isChoosingSegment = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingOptions) { routeOptions }
            .sheet(item: $placePicker) { request in
                RoutePlacePicker(request: request) { target in
                    var updated = points
                    if request.role.apply(target, to: &updated, limit: GPXRouteParser.maximumPointCount) {
                        rememberEdit()
                        points = updated
                        fitRoute()
                        confirmation = nil
                    } else {
                        showError(GPXRouteError.tooLarge.localizedDescription)
                    }
                }
            }
            .alert(
                confirmationTitle,
                isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })
            ) {
                if confirmation == .discardChanges {
                    Button("Discard Changes", role: .destructive) { dismiss() }
                    Button("Keep Editing", role: .cancel) {}
                } else if confirmation == .clearRoute {
                    Button("Clear all route points", role: .destructive) { rememberEdit(); points = [] }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: {
                if case .failure(let message) = confirmation { Text(message) }
                else if confirmation == .clearRoute {
                    Text("This removes every route point. Use Undo last change to restore them.")
                }
            }
            .onDisappear { importTask?.cancel() }
        }
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .discardChanges: String(localized: "Discard route changes?")
        case .clearRoute: String(localized: "Clear all route points?")
        case .failure, .none: String(localized: "Route needs attention")
        }
    }

    private func showError(_ message: String) { confirmation = .failure(message) }

    private var mapWaypoints: [(offset: Int, element: RouteWaypoint)] {
        let indexed = Array(points.enumerated())
        return points.count <= 100 ? indexed : indexed.filter { $0.offset == 0 || $0.offset == points.count - 1 }
    }

    private func panelHeights(for geometry: GeometryProxy) -> [CGFloat] {
        let maximum = max(220, geometry.size.height - 84)
        return [min(isPickingOnMap ? (dynamicTypeSize.isAccessibilitySize ? 250 : 184) : (dynamicTypeSize.isAccessibilitySize ? 220 : 154), maximum), min(dynamicTypeSize.isAccessibilitySize ? 430 : 320, maximum), maximum]
    }

    private func setPanel(_ stop: PanelStop) {
        panelDrag = 0
        panelStop = stop
        if stop != .collapsed { isPickingOnMap = false; mapCandidate = nil }
    }

    private func panelHandle(heights: [CGFloat]) -> some View {
        Capsule().fill(.secondary.opacity(0.4)).frame(width: 36, height: 5)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($isPanelDragging) { _, state, _ in state = true }
                .onChanged { value in
                    if abs(value.translation.height) > abs(value.translation.width) { panelDrag = value.translation.height }
                }
                .onEnded { value in
                    let movement = value.translation.height
                    guard abs(movement) > 36, abs(movement) > abs(value.translation.width) else { panelDrag = 0; return }
                    let next = min(2, max(0, panelStop.rawValue + (movement < 0 ? 1 : -1)))
                    setPanel(PanelStop(rawValue: next) ?? .medium)
                })
            .accessibilityElement()
            .accessibilityLabel("Route panel handle")
            .accessibilityValue(panelStop == .expanded ? String(localized: "Full panel") : panelStop == .medium ? String(localized: "Half panel") : String(localized: "Compact panel"))
            .accessibilityIdentifier("customRoute.panelHandle")
            .accessibilityAction(named: Text("Expand route panel")) { setPanel(.expanded) }
            .accessibilityAction(named: Text("Collapse route panel")) { setPanel(.collapsed) }
    }

    private var nextPointTitle: LocalizedStringKey {
        points.isEmpty ? "First, choose the start" : points.count == 1 ? "Next, choose the destination" : "Add a waypoint before the destination"
    }

    private var nextPointAction: LocalizedStringKey {
        points.isEmpty ? "Set as start" : points.count == 1 ? "Set as destination" : "Add waypoint"
    }

    private func applyCurrentPositionIfAvailable() {
        guard let coordinate = locationModel.currentRealCoordinate else { return }
        camera = .region(MKCoordinateRegion(center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
        isWaitingForCurrentLocation = false
    }

    private func requestCurrentPosition(reportErrors: Bool) {
        reportsLocationErrors = reportErrors
        isWaitingForCurrentLocation = true
        applyCurrentPositionIfAvailable()
        if !isWaitingForCurrentLocation { return }
        if reportErrors { locationModel.showCurrentLocation() }
        else { locationModel.prepareCurrentLocation(recenter: true) }
        if !locationModel.isFindingRealLocation {
            isWaitingForCurrentLocation = false
            if reportErrors, let message = locationModel.errorMessage { showError(message) }
        }
    }

    private func beginMapSelection() {
        mapSelectionReturnStop = panelStop == .expanded ? .expanded : .medium
        mapCandidate = nil
        panelDrag = 0
        panelStop = .collapsed
        isPickingOnMap = true
    }

    private func finishMapSelection() {
        isPickingOnMap = false
        mapCandidate = nil
        setPanel(mapSelectionReturnStop)
    }

    private var mapSelectionContent: some View {
        VStack(spacing: 6) {
            Text(nextPointTitle).font(.subheadline.weight(.semibold))
            Text(mapCandidate == nil ? "Tap the map to select a point" : "Tap elsewhere to change the selected point")
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 12) {
                Button(action: finishMapSelection) {
                    Text("Cancel").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("customRoute.cancelMapPoint")
                Button(action: confirmMapPoint) {
                    Text(nextPointAction).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(mapCandidate == nil || isReadingFile)
                .accessibilityIdentifier("customRoute.confirmMapPoint")
                .accessibilityValue(mapCandidate.map { String(format: "%.5f, %.5f", $0.latitude, $0.longitude) } ?? "")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private func confirmMapPoint() {
        guard let coordinate = mapCandidate else { return }
        var updated = points
        let role: RoutePointRole = points.isEmpty ? .start : points.count == 1 ? .destination : .waypoint
        if role.apply(LocationTarget(name: String(localized: "Map point"), subtitle: "", latitude: coordinate.latitude, longitude: coordinate.longitude),
                      to: &updated, limit: GPXRouteParser.maximumPointCount) {
            rememberEdit()
            points = updated
            finishMapSelection()
        } else { showError(GPXRouteError.tooLarge.localizedDescription) }
    }

    private var routeMap: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let route { MapPolyline(route.polyline).stroke(.blue, lineWidth: 5) }
                ForEach(mapWaypoints, id: \.element.id) { index, point in
                    Annotation(label(for: index), coordinate: point.coordinate) {
                        Text("\(index + 1)").font(.caption.bold()).padding(8)
                            .foregroundStyle(.white)
                            .background(index == 0 ? .green : index == points.count - 1 ? .orange : .blue, in: Circle())
                    }
                }
                if isPickingOnMap, let mapCandidate {
                    Annotation("Selected point", coordinate: mapCandidate, anchor: .center) {
                        Circle().stroke(.blue, lineWidth: 3)
                            .frame(width: 20, height: 20)
                            .shadow(color: .white, radius: 2)
                            .allowsHitTesting(false)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .onMapCameraChange { context in visibleRegion = context.region }
            .simultaneousGesture(SpatialTapGesture().onEnded { event in
                guard isPickingOnMap, !isReadingFile,
                      let coordinate = proxy.convert(event.location, from: .local),
                      CLLocationCoordinate2DIsValid(coordinate) else { return }
                mapCandidate = coordinate
            })
            .accessibilityIdentifier("customRoute.map")
        }
    }

    private var previewAction: some View {
        Button {
            do { try onPreview(points, coordinateMode, speed); dismiss() }
            catch { showError(error.localizedDescription) }
        } label: {
            HStack(spacing: 8) {
                if isReadingFile { ProgressView(); Text("Importing GPX…") }
                else { Label("Preview Route", systemImage: "figure.walk") }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(route == nil || isReadingFile ? Color.secondary : .white)
            .background(route == nil || isReadingFile ? Color(uiColor: .tertiarySystemFill) : Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(route == nil || isReadingFile)
        .accessibilityIdentifier("customRoute.preview")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var editorControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                importButton.frame(maxWidth: .infinity, alignment: .leading)
                undoButton.frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 8) {
                Button { isShowingOptions = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "slider.horizontal.3").frame(width: 24)
                        Text("Route options")
                        Spacer(minLength: 8)
                        Text(coordinateMode == .wgs84 ? "WGS84" : "GCJ-02").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("customRoute.options")

            }
        }
        .font(.subheadline)
        .buttonStyle(.plain)
        .disabled(isReadingFile)
    }

    private var routeOptions: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Coordinate mode", selection: $coordinateMode) {
                        Text("WGS84 unchanged").tag(FixedCoordinateMode.wgs84)
                        Text("GCJ-02 correction").tag(FixedCoordinateMode.gcj02)
                    }
                    .pickerStyle(.inline)
                } footer: {
                    Text("GPX coordinates use WGS84 by default.")
                }
                Section {
                    Text("Route calculation and GPX processing stay on this device. Map tiles may still need an internet connection.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Route options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { isShowingOptions = false } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func fitRoute() {
        guard let first = points.first else { return }
        if let geometry = try? SimulationRoute(coordinates: coordinates, name: "") {
            let rect = geometry.polyline.boundingMapRect
            var visible = rect.insetBy(dx: -max(rect.width * 0.2, 300), dy: -max(rect.height * 0.2, 300))
            // Reserve the lower map area covered by the medium route panel.
            let coveredFraction = min(0.55, 320 / max(mapSize.height, 640))
            visible.size.height /= 1 - coveredFraction
            camera = .rect(visible)
        } else {
            camera = .region(MKCoordinateRegion(center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
        }
    }

    private var importButton: some View {
        Button { isImporting = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down").frame(width: 24)
                Text("Import GPX")
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.tint)
        .accessibilityIdentifier("customRoute.import")
    }

    private var addButton: some View {
        Button(points.isEmpty ? "Choose route start" : points.count == 1 ? "Choose destination" : "Add waypoint", systemImage: "plus") {
            showPlacePicker(points.isEmpty ? .start : points.count == 1 ? .destination : .waypoint)
        }
        .frame(minHeight: 44)
        .buttonStyle(.plain)
        .controlSize(.small)
        .disabled(isReadingFile || points.count >= GPXRouteParser.maximumPointCount)
        .accessibilityIdentifier("customRoute.addWaypoint")
    }

    private func showPlacePicker(_ role: RoutePointRole) {
        let region = visibleRegion ?? points.last.map {
            MKCoordinateRegion(center: $0.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
        placePicker = RoutePlacePickerRequest(role: role, region: region)
    }

    private var undoButton: some View {
        Button {
            guard let previous = undoStates.popLast() else { return }
            points = previous.points
            coordinateMode = previous.coordinateMode
            confirmation = nil
            fitRoute()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward").frame(width: 24)
                Text("Undo route edit")
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(.tint)
        .disabled(undoStates.isEmpty)
    }

    @ViewBuilder
    private var waypointList: some View {
        if route == nil && panelStop == .expanded {
            Text("Choose at least two different route points to preview.")
                .font(.caption).foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
        if points.isEmpty {
            routePlaceholder("Choose route start", role: .start)
                .listRowBackground(Color.clear)
        }
        ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            HStack(spacing: 0) {
                Button { showPlacePicker(.replace(point.id)) } label: {
                    HStack(spacing: 12) {
                        Circle().fill(index == 0 ? .green : index == points.count - 1 ? .orange : .blue)
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label(for: index)).font(.caption).foregroundStyle(.secondary)
                            Text(point.name ?? String(localized: "Map point"))
                                .font(.body.weight(.medium)).foregroundStyle(.primary)
                                .lineLimit(panelStop == .expanded ? nil : 1)
                            if panelStop == .expanded {
                                Text(point.address.flatMap { $0.isEmpty ? nil : $0 } ?? String(format: "%.5f, %.5f", point.coordinate.latitude, point.coordinate.longitude))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: panelStop == .expanded ? 56 : 44, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Searches for a replacement route point")
                .accessibilityIdentifier("customRoute.point.\(point.id.uuidString)")
                Button { removePoint(point.id) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete route point")
                .accessibilityValue(point.name ?? label(for: index))
                .accessibilityHint("Removes only this point")
                .accessibilityIdentifier("customRoute.delete.\(point.id.uuidString)")
            }
            .disabled(isReadingFile)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 16))
            .contextMenu {
                Button("Show route point", systemImage: "mappin") {
                    camera = .region(MKCoordinateRegion(center: point.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
                }
                Button("Delete route point", systemImage: "trash", role: .destructive) {
                    removePoint(point.id)
                }
            }
        }
        .onMove { source, destination in
            rememberEdit()
            points.move(fromOffsets: source, toOffset: destination)
        }
        .moveDisabled(isReadingFile)
        if points.count < 2 {
            routePlaceholder("Choose destination", role: .destination)
                .disabled(points.isEmpty).listRowBackground(Color.clear)
        }
    }

    private func removePoint(_ id: UUID) {
        guard points.contains(where: { $0.id == id }) else { return }
        rememberEdit()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
            points.removeAll { $0.id == id }
        }
    }

    private func routePlaceholder(_ title: LocalizedStringKey, role: RoutePointRole) -> some View {
        Button { showPlacePicker(role) } label: {
            Label(title, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func label(for index: Int) -> String {
        if index == 0 { return String(localized: "Route Start") }
        if index == points.count - 1 { return String(localized: "Destination") }
        return String(format: NSLocalizedString("Waypoint %lld", comment: ""), index)
    }

    private struct RouteEditSnapshot {
        let points: [RouteWaypoint]
        let coordinateMode: FixedCoordinateMode
    }

    private func rememberEdit() {
        undoStates.append(RouteEditSnapshot(points: points, coordinateMode: coordinateMode))
        if undoStates.count > 20 { undoStates.removeFirst() }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let failure):
            if (failure as NSError).code != NSUserCancelledError { showError(failure.localizedDescription) }
        case .success(let urls):
            guard let url = urls.first else { return }
            isReadingFile = true
            confirmation = nil
            importTask = Task { @MainActor in
                defer { isReadingFile = false }
                do {
                    let imported = try await Task.detached(priority: .userInitiated) {
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        // Bound the read itself, including providers without a known file size.
                        let handle = try FileHandle(forReadingFrom: url)
                        defer { try? handle.close() }
                        let data = try handle.read(upToCount: GPXRouteParser.maximumFileSize + 1) ?? Data()
                        return try GPXRouteParser.parse(data)
                    }.value
                    guard !Task.isCancelled else { return }
                    if imported.count == 1 { use(imported[0]) }
                    else { segments = imported; isChoosingSegment = true }
                } catch {
                    guard !Task.isCancelled else { return }
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func use(_ segment: GPXRouteSegment) {
        guard let route = try? SimulationRoute(coordinates: segment.coordinates, name: "") else {
            showError(GPXRouteError.invalidPoints.localizedDescription); return
        }
        rememberEdit()
        coordinateMode = .wgs84
        points = segment.coordinates.map { RouteWaypoint(coordinate: $0) }
        let rect = route.polyline.boundingMapRect
        camera = .rect(rect.insetBy(dx: -max(rect.width * 0.2, 300), dy: -max(rect.height * 0.2, 300)))
        confirmation = nil
    }
}
