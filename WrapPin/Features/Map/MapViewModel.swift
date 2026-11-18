import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class MapViewModel: NSObject, MKLocalSearchCompleterDelegate {
    var searchQuery = ""
    var searchSuggestions: [MapSearchSuggestion] = []
    var selectedLocation: LocationTarget?
    var isSearching = false
    var isResolvingAddress = false
    var isFindingRealLocation = false
    private(set) var realLocationRevision = 0
    var currentRealCoordinate: CLLocationCoordinate2D? {
        guard isRealLocationCacheTrusted else { return nil }
        // A fresh approximate fix is still useful for centering the map, just as on Home.
        return [lastRealLocation, locationManager.location].compactMap { $0 }
            .filter { !Self.isSimulated($0) && $0.horizontalAccuracy >= 0 && Date().timeIntervalSince($0.timestamp) <= 300 }
            .max(by: { $0.timestamp < $1.timestamp })?.coordinate
    }
    var errorMessage: String? {
        didSet { scheduleErrorDismissal() }
    }
    var cameraPosition: MapCameraPosition
    var overseasResults: [OverseasPlace] = []
    // Route-point selection presents candidates rather than choosing the first match.
    private(set) var searchResults: [LocationTarget] = []
    var searchRegion: MKCoordinateRegion?
    private let selectsFirstSearchResult: Bool
    private let enablesSearchSuggestions: Bool
    @ObservationIgnored private var searchRequestID: UUID?
    @ObservationIgnored private var placeSearch: MKLocalSearch?
    @ObservationIgnored private let searchProvider: (@MainActor (MKLocalSearch.Request) async throws -> [MKMapItem])?
    private(set) var isOverseasSearch = UserDefaults.standard.bool(forKey: MapViewModel.overseasSearchKey)

    @ObservationIgnored
    private let searchCompleter = MKLocalSearchCompleter()
    @ObservationIgnored
    private let locationManager = CLLocationManager()
    @ObservationIgnored
    private var recenterOnNextRealLocation = false
    @ObservationIgnored
    private var locationRequestStartedAt: Date?
    @ObservationIgnored
    private var locationTimeout: Task<Void, Never>?
    @ObservationIgnored
    private var shouldReportLocationErrors = false
    @ObservationIgnored
    private var lastRealLocation: CLLocation?
    @ObservationIgnored
    private var isRealLocationCacheTrusted = true
    @ObservationIgnored
    private var requiresFreshRealLocation = false
    @ObservationIgnored
    private var activeAddressLookupID: UUID?
    @ObservationIgnored
    private var errorDismissalTask: Task<Void, Never>?
    @ObservationIgnored
    private lazy var overseasQuota = Self.loadOverseasQuota()
    @ObservationIgnored
    private lazy var overseasCache = Self.loadOverseasCache()

    private static let overseasSearchKey = "overseasSearchEnabled"
    private static let overseasQuotaKey = "overseasSearchQuota"

    override convenience init() {
        self.init(selectsFirstSearchResult: true)
    }

    init(
        selectsFirstSearchResult: Bool,
        enablesSearchSuggestions: Bool = true,
        searchProvider: (@MainActor (MKLocalSearch.Request) async throws -> [MKMapItem])? = nil
    ) {
        self.selectsFirstSearchResult = selectsFirstSearchResult
        self.enablesSearchSuggestions = enablesSearchSuggestions
        self.searchProvider = searchProvider
        cameraPosition = .automatic
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = selectsFirstSearchResult
            ? [.address, .pointOfInterest, .query] : [.address, .pointOfInterest]
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    var isShowingSuggestions: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !searchSuggestions.isEmpty
    }

    var isShowingOverseasResults: Bool {
        !overseasResults.isEmpty
    }

    var isOverseasSearchAvailable: Bool {
        OverseasPlaceSearch.isConfigured
    }

    /// Mainland Apple Maps data rarely includes overseas places, so overseas
    /// search uses its own service instead of MapKit.
    private var usesOverseasSearch: Bool {
        isOverseasSearch && isOverseasSearchAvailable
    }

    func setOverseasSearch(_ isEnabled: Bool) {
        guard isEnabled != isOverseasSearch else { return }
        isOverseasSearch = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.overseasSearchKey)
        updateSearchQuery(searchQuery)
    }

    func updateSearchQuery(_ query: String) {
        invalidateSearchRequest()
        searchQuery = query
        errorMessage = nil
        overseasResults = []
        searchResults = []
        searchSuggestions = []

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch coordinateInput(from: trimmedQuery) {
        case .coordinate, .invalid:
            searchSuggestions = []
            searchCompleter.queryFragment = ""
            return
        case .notCoordinates:
            break
        }

        // Overseas results are fetched only on submit, never while typing,
        // so each search spends at most one request of the shared quota.
        guard enablesSearchSuggestions, !usesOverseasSearch, trimmedQuery.count >= 2 else {
            searchSuggestions = []
            searchCompleter.queryFragment = ""
            return
        }

        if let searchRegion { searchCompleter.region = searchRegion }
        searchCompleter.queryFragment = trimmedQuery
    }

    func selectDroppedPin(at coordinate: CLLocationCoordinate2D) async {
        await selectCoordinate(
            coordinate,
            fallbackName: String(localized: "Dropped Pin"),
            recenter: false
        )
    }

    /// The route picker keeps its completion list on submit instead of replacing it
    /// with a separate keyword search. Coordinates and the overseas provider retain
    /// their existing explicit-submit behavior.
    func submitRouteSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        if case .notCoordinates = coordinateInput(from: query), !usesOverseasSearch {
            errorMessage = nil
            guard enablesSearchSuggestions else { return }
            if let searchRegion { searchCompleter.region = searchRegion }
            if searchCompleter.queryFragment != query || searchSuggestions.isEmpty {
                if searchCompleter.queryFragment == query { searchCompleter.queryFragment = "" }
                searchCompleter.queryFragment = query
            }
            return
        }
        await search()
    }

    func search() async {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        switch coordinateInput(from: trimmedQuery) {
        case .coordinate(let coordinate):
            if !selectsFirstSearchResult {
                searchSuggestions = []
                overseasResults = []
                errorMessage = nil
                searchResults = [LocationTarget(name: String(localized: "Entered Location"),
                    subtitle: String(localized: "Entered using coordinates"),
                    latitude: coordinate.latitude, longitude: coordinate.longitude)]
                return
            }
            isSearching = true
            errorMessage = nil
            resetSearchField()
            await selectCoordinate(
                coordinate,
                fallbackName: String(localized: "Entered Location"),
                recenter: true
            )
            isSearching = false
            return
        case .invalid:
            searchSuggestions = []
            errorMessage = String(localized: "Enter latitude from −90 to 90 and longitude from −180 to 180.")
            return
        case .notCoordinates:
            break
        }

        if usesOverseasSearch {
            await performOverseasSearch(for: trimmedQuery)
        } else {
            await performSearch(for: trimmedQuery)
        }
    }

    func selectOverseasPlace(_ place: OverseasPlace) {
        let target = LocationTarget(
            name: place.name,
            subtitle: place.address.isEmpty
                ? String(localized: "Location details unavailable")
                : place.address,
            latitude: place.latitude,
            longitude: place.longitude
        )
        selectedLocation = target
        errorMessage = nil
        center(on: target)
        resetSearchField()
    }

    @discardableResult
    func selectSuggestion(_ suggestion: MapSearchSuggestion, directlySelect: Bool = false) async -> LocationTarget? {
        // Preserve the selected place instead of broadening it into a new keyword search.
        let completion = searchCompleter.results.first {
            $0.title == suggestion.title && $0.subtitle == suggestion.subtitle
        }
        guard !directlySelect || completion != nil || searchProvider != nil else {
            errorMessage = String(localized: "Search is unavailable right now.")
            return nil
        }
        searchQuery = suggestion.title
        searchSuggestions = []

        let query = [suggestion.title, suggestion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return await performSearch(for: query, completion: completion, directlySelect: directlySelect)
    }

    func show(_ target: LocationTarget) {
        selectedLocation = target
        resetSearchField()
        errorMessage = nil
        center(on: target)
    }

    func refreshAddressIfNeeded(for target: LocationTarget) async -> LocationTarget? {
        guard target.needsAddressRefresh, selectedLocation?.id == target.id else { return nil }

        await selectCoordinate(
            target.coordinate,
            fallbackName: refreshedFallbackName(for: target),
            recenter: false,
            preserveName: !target.usesGenericMapName
        )

        guard selectedLocation?.id == target.id else { return nil }
        return selectedLocation
    }

    private func refreshedFallbackName(for target: LocationTarget) -> String {
        let storedName = target.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["Entered Location", "坐标位置"].contains(storedName) {
            return String(localized: "Entered Location")
        }
        if target.usesGenericMapName {
            return String(localized: "Dropped Pin")
        }
        return target.name
    }

    func center(on target: LocationTarget) {
        center(on: target.coordinate)
    }

    func center(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
    }

    func show(_ route: SimulationRoute) {
        show([route])
    }

    func show(_ routes: [SimulationRoute]) {
        let routeRect = routes.reduce(MKMapRect.null) { $0.union($1.polyline.boundingMapRect) }
        guard !routeRect.isNull, !routeRect.isEmpty else { return }

        let horizontalPadding = max(routeRect.size.width * 0.24, 1_200)
        let verticalPadding = max(routeRect.size.height * 0.30, 1_200)
        cameraPosition = .rect(
            routeRect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
        )
    }

    func prepareCurrentLocation(recenter: Bool = false) {
        requestCurrentLocation(
            recenter: recenter,
            reportErrors: false,
            requireFreshLocation: false
        )
    }

    func showRealLocationAfterSession() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            self?.refreshRealLocationAfterRestoration()
        }
    }

    func refreshRealLocationAfterRestoration() {
        requestCurrentLocation(
            recenter: true,
            reportErrors: true,
            requireFreshLocation: true
        )
    }

    func showCurrentLocation() {
        if let cachedLocation = cachedRealLocation() {
            center(on: cachedLocation)
            errorMessage = nil
            isFindingRealLocation = false
            requestCurrentLocation(
                recenter: false,
                reportErrors: false,
                requireFreshLocation: false
            )
            return
        }

        requestCurrentLocation(
            recenter: true,
            reportErrors: true,
            requireFreshLocation: !isRealLocationCacheTrusted
        )
    }

    func invalidateRealLocationCache() {
        lastRealLocation = nil
        isRealLocationCacheTrusted = false
        realLocationRevision &+= 1
    }

    @discardableResult
    private func performSearch(for query: String, completion: MKLocalSearchCompletion? = nil,
                               directlySelect: Bool = false) async -> LocationTarget? {
        invalidateSearchRequest()
        let requestID = UUID()
        searchRequestID = requestID
        isSearching = true
        errorMessage = nil
        searchSuggestions = []
        searchResults = []
        defer {
            if searchRequestID == requestID {
                searchRequestID = nil
                placeSearch = nil
                isSearching = false
            }
        }

        let request = completion.map { MKLocalSearch.Request(completion: $0) } ?? MKLocalSearch.Request()
        if completion == nil { request.naturalLanguageQuery = query }
        if let searchRegion { request.region = searchRegion }
        let search = MKLocalSearch(request: request)
        placeSearch = search
        do {
            let items: [MKMapItem]
            if let searchProvider { items = try await searchProvider(request) }
            else { items = try await search.start().mapItems }
            guard !Task.isCancelled, searchRequestID == requestID else { return nil }
            let targets = items.compactMap { item -> LocationTarget? in
                let coordinate = MapKitCompatibility.coordinate(of: item)
                guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
                return LocationTarget(name: item.name ?? query,
                    subtitle: placeDescription(for: item),
                    latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
            guard let first = targets.first else {
                errorMessage = String(localized: "No matching place found. You can also paste coordinates, such as 35.6586, 139.7454.")
                return nil
            }
            if directlySelect { return first }
            if selectsFirstSearchResult {
                selectedLocation = first
                center(on: first)
                resetSearchField()
            } else {
                // Collapse duplicate map items while preserving the provider's order.
                var seen: Set<String> = []
                searchResults = Array(targets.filter { seen.insert($0.id).inserted }.prefix(20))
            }
        } catch is CancellationError {
            return nil
        } catch {
            guard !Task.isCancelled, searchRequestID == requestID else { return nil }
            errorMessage = String(localized: "Search is unavailable right now.")
        }
        return nil
    }

    private func performOverseasSearch(for query: String) async {
        invalidateSearchRequest()
        let requestID = UUID()
        searchRequestID = requestID
        isSearching = true
        errorMessage = nil
        overseasResults = []
        defer { if searchRequestID == requestID { searchRequestID = nil; isSearching = false } }

        // Route pickers and the main map share the same persisted daily allowance.
        overseasQuota = Self.loadOverseasQuota()
        overseasCache = Self.loadOverseasCache()
        let now = Date()
        let places: [OverseasPlace]
        if let cached = overseasCache.places(for: query, at: now) {
            places = cached
        } else {
            let day = OverseasSearchQuota.dayKey(for: now)
            guard overseasQuota.canSearch(on: day) else {
                errorMessage = String(localized: "This iPhone has reached today's overseas search limit. You can paste coordinates instead.")
                return
            }
            // Counted before sending, so failing requests cannot be retried endlessly.
            overseasQuota.recordSearch(on: day)
            Self.saveOverseasQuota(overseasQuota)

            do {
                places = try await OverseasPlaceSearch.search(query)
            } catch is CancellationError {
                return
            } catch OverseasSearchError.network {
                guard !Task.isCancelled, searchRequestID == requestID else { return }
                errorMessage = String(localized: "Overseas search could not be reached. In mainland China it may need a proxy; you can also paste coordinates instead.")
                return
            } catch {
                guard !Task.isCancelled, searchRequestID == requestID else { return }
                errorMessage = String(localized: "Overseas search is unavailable right now. You can paste coordinates instead.")
                return
            }
            overseasCache = Self.loadOverseasCache()
            overseasCache.store(places, for: query, at: now)
            Self.saveOverseasCache(overseasCache)
        }

        // The user may have edited or cleared the query while waiting.
        guard !Task.isCancelled, searchRequestID == requestID,
              searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
        guard !places.isEmpty else {
            errorMessage = String(localized: "No overseas place found. Try the local or English name, or paste coordinates.")
            return
        }
        overseasResults = places
    }

    private static func loadOverseasQuota() -> OverseasSearchQuota {
        guard let data = UserDefaults.standard.data(forKey: overseasQuotaKey),
              let quota = try? JSONDecoder().decode(OverseasSearchQuota.self, from: data)
        else { return OverseasSearchQuota() }
        return quota
    }

    private static func saveOverseasQuota(_ quota: OverseasSearchQuota) {
        guard let data = try? JSONEncoder().encode(quota) else { return }
        UserDefaults.standard.set(data, forKey: overseasQuotaKey)
    }

    private static var overseasCacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OverseasSearchCache.json")
    }

    private static func loadOverseasCache() -> OverseasSearchCache {
        guard let url = overseasCacheURL,
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(OverseasSearchCache.self, from: data)
        else { return OverseasSearchCache() }
        return cache
    }

    private static func saveOverseasCache(_ cache: OverseasSearchCache) {
        guard let url = overseasCacheURL, let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func selectCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        fallbackName: String,
        recenter: Bool,
        preserveName: Bool = false
    ) async {
        errorMessage = nil
        let lookupID = UUID()
        activeAddressLookupID = lookupID
        isResolvingAddress = true
        defer {
            if activeAddressLookupID == lookupID {
                activeAddressLookupID = nil
                isResolvingAddress = false
            }
        }

        let pendingTarget = LocationTarget(
            name: fallbackName,
            subtitle: String(localized: "Finding nearby address…"),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        selectedLocation = pendingTarget

        if recenter {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
            )
        }

        let item = await reverseGeocode(coordinate)
        guard
            activeAddressLookupID == lookupID,
            selectedLocation?.id == pendingTarget.id
        else { return }

        if let item {
            selectedLocation = LocationTarget(
                name: preserveName ? fallbackName : (item.name ?? fallbackName),
                subtitle: placeDescription(for: item),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        } else {
            selectedLocation = LocationTarget(
                name: fallbackName,
                subtitle: unavailableAddressDescription(for: coordinate),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> MKMapItem? {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        for attempt in 0..<2 {
            do {
                if let item = try await MapKitCompatibility.reverseGeocode(location) {
                    return item
                }
            } catch is CancellationError {
                return nil
            } catch {
                // A short second attempt covers transient network and service failures.
            }

            if attempt == 0 {
                do {
                    try await Task.sleep(for: .milliseconds(450))
                } catch {
                    return nil
                }
            }
        }

        return nil
    }

    private func unavailableAddressDescription(
        for coordinate: CLLocationCoordinate2D
    ) -> String {
        let coordinates = String(
            format: "%.6f, %.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude
        )
        return String(
            format: NSLocalizedString("Address unavailable · %@", comment: ""),
            coordinates
        )
    }

    private func coordinateInput(from query: String) -> CoordinateInput {
        switch CoordinateInputParser.parse(query) {
        case .notCoordinates:
            return .notCoordinates
        case .invalid:
            return .invalid
        case .coordinate(let latitude, let longitude):
            return .coordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // Messages fade after a few seconds, longer ones staying long enough to
    // read, so a failed search does not leave a banner over the map.
    private func scheduleErrorDismissal() {
        errorDismissalTask?.cancel()
        guard selectsFirstSearchResult, let message = errorMessage else { return }
        let seconds = min(8, max(4, Double(message.count) * 0.12))
        errorDismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.errorMessage == message else { return }
            self.errorMessage = nil
        }
    }

    func clearSearch() {
        resetSearchField()
        errorMessage = nil
    }

    func clearSelectedLocation() {
        selectedLocation = nil
        errorMessage = nil
    }

    private func invalidateSearchRequest() {
        searchRequestID = nil
        placeSearch?.cancel()
        placeSearch = nil
        isSearching = false
    }

    private func resetSearchField() {
        invalidateSearchRequest()
        searchResults = []
        searchQuery = ""
        searchSuggestions = []
        overseasResults = []
        searchCompleter.queryFragment = ""
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let suggestions = completer.results.prefix(6).map {
            MapSearchSuggestion(title: $0.title, subtitle: $0.subtitle)
        }

        Task { @MainActor [weak self] in
            guard let self, !self.searchQuery.isEmpty, !self.usesOverseasSearch,
                  !self.isSearching, self.searchResults.isEmpty else { return }
            self.searchSuggestions = suggestions
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        Task { @MainActor [weak self] in
            self?.searchSuggestions = []
        }
    }

    private func placeDescription(for item: MKMapItem) -> String {
        let invisibleCharacters = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
        )
        let candidates = MapKitCompatibility.addressCandidates(for: item)

        for candidate in candidates {
            let detail = candidate?.trimmingCharacters(in: invisibleCharacters) ?? ""
            if !detail.isEmpty {
                return detail
            }
        }
        return String(localized: "Location details unavailable")
    }

    private func requestCurrentLocation(
        recenter: Bool,
        reportErrors: Bool,
        requireFreshLocation: Bool
    ) {
        shouldReportLocationErrors = reportErrors
        requiresFreshRealLocation = requireFreshLocation
        switch locationManager.authorizationStatus {
        case .notDetermined:
            recenterOnNextRealLocation = recenter
            isFindingRealLocation = recenter
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            recenterOnNextRealLocation = recenter
            isFindingRealLocation = recenter
            locationRequestStartedAt = Date()
            locationManager.startUpdatingLocation()
            locationTimeout?.cancel()
            locationTimeout = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    return
                }

                guard let self, self.locationRequestStartedAt != nil else { return }
                // A simulated-location session can take a little longer than a
                // normal location request to hand control back to Core Location.
                // Do not turn a delayed, fresh callback into an error after the
                // session itself has already ended.
                self.isFindingRealLocation = false
                self.errorMessage = nil

                do {
                    try await Task.sleep(for: .seconds(45))
                } catch {
                    return
                }

                guard self.locationRequestStartedAt != nil else { return }
                self.locationManager.stopUpdatingLocation()
                self.locationRequestStartedAt = nil
                self.recenterOnNextRealLocation = false
                self.requiresFreshRealLocation = false
            }
        case .denied, .restricted:
            isFindingRealLocation = false
            if recenter && shouldReportLocationErrors {
                errorMessage = String(localized: "Allow Location access in Settings to show your real position.")
            }
        @unknown default:
            break
        }
    }

    private func receiveLocations(_ locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        // After a session stops, Core Location can keep delivering the last
        // simulated fix with a new timestamp until it reacquires the real one.
        // Keep waiting instead of caching it as this iPhone's real location.
        guard !Self.isSimulated(location) else { return }
        if requiresFreshRealLocation,
           let locationRequestStartedAt,
           location.timestamp < locationRequestStartedAt.addingTimeInterval(-0.5) {
            return
        }

        lastRealLocation = location
        isRealLocationCacheTrusted = true
        realLocationRevision &+= 1
        requiresFreshRealLocation = false
        locationManager.stopUpdatingLocation()
        locationTimeout?.cancel()
        locationTimeout = nil
        self.locationRequestStartedAt = nil
        isFindingRealLocation = false

        guard recenterOnNextRealLocation else { return }
        recenterOnNextRealLocation = false
        errorMessage = nil
        center(on: location)
    }

    private func center(on location: CLLocation) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            )
        )
    }

    private func cachedRealLocation() -> CLLocation? {
        guard isRealLocationCacheTrusted else { return nil }

        let candidates = [lastRealLocation, locationManager.location]
            .compactMap { $0 }
            .filter {
                !Self.isSimulated($0)
                    && $0.horizontalAccuracy >= 0
                    && $0.horizontalAccuracy <= 1_000
                    && Date().timeIntervalSince($0.timestamp) <= 300
            }

        return candidates.max { $0.timestamp < $1.timestamp }
    }

    private static func isSimulated(_ location: CLLocation) -> Bool {
        location.sourceInformation?.isSimulatedBySoftware == true
    }
}

private enum CoordinateInput {
    case notCoordinates
    case invalid
    case coordinate(CLLocationCoordinate2D)
}

extension MapViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                requestCurrentLocation(
                    recenter: recenterOnNextRealLocation,
                    reportErrors: shouldReportLocationErrors,
                    requireFreshLocation: requiresFreshRealLocation
                )
            case .denied, .restricted:
                isFindingRealLocation = false
                if recenterOnNextRealLocation {
                    recenterOnNextRealLocation = false
                    if shouldReportLocationErrors {
                        errorMessage = String(localized: "Allow Location access in Settings to show your real position.")
                    }
                }
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            receiveLocations(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            let locationError = error as NSError
            if locationError.domain == kCLErrorDomain,
               locationError.code == CLError.Code.locationUnknown.rawValue {
                return
            }

            locationManager.stopUpdatingLocation()
            locationTimeout?.cancel()
            locationTimeout = nil
            locationRequestStartedAt = nil
            isFindingRealLocation = false
            if recenterOnNextRealLocation {
                recenterOnNextRealLocation = false
                if shouldReportLocationErrors {
                    errorMessage = String(localized: "Your real location is not available yet.")
                }
            }
        }
    }
}

struct MapSearchSuggestion: Identifiable, Sendable {
    let title: String
    let subtitle: String

    var id: String {
        "\(title)|\(subtitle)"
    }
}
