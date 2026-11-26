import SwiftUI

struct SavedPlacesView: View {
    private enum ClearTarget: String, Identifiable {
        case favouriteRoutes
        case favourites
        case history

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var favouriteBeingRenamed: LocationTarget?
    @State private var favouriteName = ""
    @State private var routeBeingRenamed: SavedCustomRoute?
    @State private var routeName = ""
    @State private var clearTarget: ClearTarget?
    @State private var editMode: EditMode = .inactive

    let favourites: [LocationTarget]
    let history: [LocationTarget]
    var favouriteRoutes: [SavedCustomRoute] = []
    var routeHistory: [SavedCustomRoute] = []
    let shouldShowFavouriteReorderHint: Bool
    let isFavourite: (LocationTarget) -> Bool
    var isFavouriteRoute: (SavedCustomRoute) -> Bool = { _ in false }
    let onSelect: (LocationTarget) -> Void
    var onSelectRoute: (SavedCustomRoute) -> Void = { _ in }
    let onToggleFavourite: (LocationTarget) -> Void
    var onToggleFavouriteRoute: (SavedCustomRoute) -> Void = { _ in }
    let onDeleteFavourite: (LocationTarget) -> Void
    var onDeleteFavouriteRoute: (SavedCustomRoute) -> Void = { _ in }
    let onMoveFavourites: (IndexSet, Int) -> Void
    var onMoveFavouriteRoutes: (IndexSet, Int) -> Void = { _, _ in }
    let onDismissFavouriteReorderHint: () -> Void
    let onRenameFavourite: (LocationTarget, String) -> Void
    var onRenameFavouriteRoute: (SavedCustomRoute, String) -> Void = { _, _ in }
    let onDeleteHistory: (LocationTarget) -> Void
    var onDeleteRouteHistory: (SavedCustomRoute) -> Void = { _ in }
    let onClearFavourites: () -> Void
    var onClearFavouriteRoutes: () -> Void = {}
    let onClearHistory: () -> Void
    var onClearRouteHistory: () -> Void = {}

    var body: some View {
        NavigationStack {
            List {
                if !favouriteRoutes.isEmpty {
                    Section {
                        ForEach(favouriteRoutes) { route in
                            SavedCustomRouteRow(
                                route: route,
                                isFavourite: true,
                                onSelect: { selectRoute(route) },
                                onToggleFavourite: { onToggleFavouriteRoute(route) },
                                onRename: editMode.isEditing ? nil : { beginRenamingRoute(route) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteFavouriteRoute(route)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    beginRenamingRoute(route)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onMove(perform: onMoveFavouriteRoutes)
                    } header: {
                        HStack {
                            Text("Favourite Routes")
                            Spacer()
                            Button("Clear") {
                                clearTarget = .favouriteRoutes
                            }
                            .textCase(nil)
                        }
                    }
                }

                Section {
                    if favourites.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "heart",
                            message: "Tap the heart on any selected place to save it."
                        )
                    } else {
                        ForEach(favourites) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "heart.fill",
                                isFavourite: true,
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) },
                                onRename: editMode.isEditing ? nil : { beginRenaming(location) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteFavourite(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    beginRenaming(location)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onMove(perform: onMoveFavourites)
                    }
                } header: {
                    HStack {
                        Text("Favourites")
                        Spacer()
                        if !favourites.isEmpty {
                            Button("Clear") {
                                clearTarget = .favourites
                            }
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if shouldShowFavouriteReorderHint && (favourites.count >= 2 || favouriteRoutes.count >= 2) {
                        Text("Tap Edit to rearrange favourites.")
                    }
                }

                Section {
                    if history.isEmpty && routeHistory.isEmpty {
                        EmptySavedPlacesRow(
                            symbol: "clock",
                            message: "Places you use will appear here."
                        )
                    } else {
                        ForEach(routeHistory) { route in
                            SavedCustomRouteRow(
                                route: route,
                                isFavourite: isFavouriteRoute(route),
                                onSelect: { selectRoute(route) },
                                onToggleFavourite: { onToggleFavouriteRoute(route) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteRouteHistory(route)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        ForEach(history) { location in
                            SavedPlaceRow(
                                location: location,
                                symbol: "clock.fill",
                                isFavourite: isFavourite(location),
                                onSelect: { select(location) },
                                onToggleFavourite: { onToggleFavourite(location) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteHistory(location)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("History")
                        Spacer()
                        if !history.isEmpty || !routeHistory.isEmpty {
                            Button("Clear") {
                                clearTarget = .history
                            }
                            .textCase(nil)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !favourites.isEmpty || !favouriteRoutes.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editMode.isEditing ? "Done" : "Edit") {
                            if !editMode.isEditing {
                                onDismissFavouriteReorderHint()
                            }
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                            .accessibilityLabel("Reorder favourites")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Rename Favourite",
                isPresented: Binding(
                    get: { favouriteBeingRenamed != nil },
                    set: { if !$0 { favouriteBeingRenamed = nil } }
                ),
                presenting: favouriteBeingRenamed
            ) { location in
                TextField("Favourite name", text: $favouriteName)
                    .accessibilityIdentifier("favourites.rename.field")
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    onRenameFavourite(location, favouriteName)
                }
                .disabled(favouriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: { _ in
                Text("Give this saved place a name that is easy to recognise.")
            }
            .alert(
                "Rename Route",
                isPresented: Binding(
                    get: { routeBeingRenamed != nil },
                    set: { if !$0 { routeBeingRenamed = nil } }
                ),
                presenting: routeBeingRenamed
            ) { route in
                TextField("Route name", text: $routeName)
                    .accessibilityIdentifier("favouriteRoutes.rename.field")
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    onRenameFavouriteRoute(route, routeName)
                }
                .disabled(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: { _ in
                Text("Give this saved route a name that is easy to recognise.")
            }
            .confirmationDialog(
                clearConfirmationTitle,
                isPresented: Binding(
                    get: { clearTarget != nil },
                    set: { if !$0 { clearTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(clearConfirmationButton, role: .destructive) {
                    performClear()
                }
                Button("Cancel", role: .cancel) {
                    clearTarget = nil
                }
            } message: {
                Text(clearConfirmationMessage)
            }
        }
    }

    private func select(_ location: LocationTarget) {
        onSelect(location)
        dismiss()
    }

    private func selectRoute(_ route: SavedCustomRoute) {
        onSelectRoute(route)
        dismiss()
    }

    private func beginRenaming(_ location: LocationTarget) {
        favouriteName = location.name
        favouriteBeingRenamed = location
    }

    private func beginRenamingRoute(_ route: SavedCustomRoute) {
        routeName = route.name
        routeBeingRenamed = route
    }

    private var clearConfirmationTitle: String {
        switch clearTarget {
        case .favouriteRoutes: String(localized: "Clear all favourite routes?")
        case .favourites: String(localized: "Clear all favourites?")
        case .history: String(localized: "Clear location history?")
        case nil: String(localized: "Clear saved places?")
        }
    }

    private var clearConfirmationButton: String {
        switch clearTarget {
        case .favouriteRoutes: String(localized: "Clear Favourite Routes")
        case .favourites: String(localized: "Clear Favourites")
        case .history: String(localized: "Clear History")
        case nil: String(localized: "Clear")
        }
    }

    private var clearConfirmationMessage: String {
        switch clearTarget {
        case .favouriteRoutes: String(localized: "Every favourite custom route will be removed. Your saved places and history will be kept.")
        case .favourites: String(localized: "Every favourite will be removed. Your history will be kept.")
        case .history: String(localized: "Every recently used location will be removed. Your favourites will be kept.")
        case nil: String(localized: "This cannot be undone.")
        }
    }

    private func performClear() {
        switch clearTarget {
        case .favouriteRoutes:
            onClearFavouriteRoutes()
        case .favourites:
            onClearFavourites()
        case .history:
            onClearHistory()
            onClearRouteHistory()
        case nil:
            break
        }
        clearTarget = nil
    }
}

private struct SavedCustomRouteRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let route: SavedCustomRoute
    let isFavourite: Bool
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void
    var onRename: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(route.name)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text(routeSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(route.name), \(routeSummary)")
            .accessibilityHint("Loads this custom route")

            HStack(spacing: 2) {
                if let onRename {
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.tint)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rename Route")
                    .accessibilityIdentifier("favouriteRoutes.rename")
                }

                Button(action: onToggleFavourite) {
                    Image(systemName: isFavourite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavourite ? .pink : .secondary)
                        .symbolEffect(.bounce, value: isFavourite)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFavourite)
                .accessibilityLabel(isFavourite ? "Remove route from favourites" : "Save route to favourites")
            }
        }
    }

    private var routeSummary: String {
        let modeText = route.coordinateMode == .gcj02 ? "GCJ-02" : "WGS84"
        return String(
            format: NSLocalizedString("%lld points · %.1f km/h · %@", comment: ""),
            route.points.count,
            route.speedKilometresPerHour,
            modeText
        )
    }
}

private struct SavedPlaceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let location: LocationTarget
    let symbol: String
    let isFavourite: Bool
    let onSelect: () -> Void
    let onToggleFavourite: () -> Void
    var onRename: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(symbol.hasPrefix("heart") ? .pink : .blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(location.name)
                            .foregroundStyle(.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text(location.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(locationAccessibilityLabel)
            .accessibilityHint("Selects this location")

            HStack(spacing: 2) {
                if let onRename {
                    Button(action: onRename) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.tint)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rename Favourite")
                    .accessibilityIdentifier("favourites.rename")
                }

                Button(action: onToggleFavourite) {
                    Image(systemName: isFavourite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavourite ? .pink : .secondary)
                        .symbolEffect(.bounce, value: isFavourite)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFavourite)
                .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
            }
        }
    }

    private var locationAccessibilityLabel: String {
        guard !location.subtitle.isEmpty else { return location.name }
        return "\(location.name), \(location.subtitle)"
    }
}

private struct EmptySavedPlacesRow: View {
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
}
