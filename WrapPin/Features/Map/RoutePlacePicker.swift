import MapKit
import SwiftUI

/// Search only selects a point. It never starts a location session or requests directions.
struct RoutePlacePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchModel = MapViewModel(selectsFirstSearchResult: false)
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool
    let request: RoutePlacePickerRequest
    let onSelect: (LocationTarget) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MapSearchBar(
                    query: Binding(get: { searchModel.searchQuery }, set: { searchModel.updateSearchQuery($0) }),
                    isFocused: $isFocused,
                    isSearching: searchModel.isSearching,
                    isOverseasSearch: searchModel.isOverseasSearchAvailable ? searchModel.isOverseasSearch : nil,
                    onToggleOverseasSearch: { searchModel.setOverseasSearch(!searchModel.isOverseasSearch) },
                    onSubmit: { performSearch() },
                    onClear: searchModel.clearSearch,
                    fieldIdentifier: "routePlace.query"
                )
                .padding(.horizontal, 16)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if let error = searchModel.errorMessage {
                            Text(error).font(.subheadline).foregroundStyle(.red)
                                .accessibilityIdentifier("routePlace.error")
                        }
                        if searchModel.isShowingSuggestions {
                            SearchSuggestionsView(suggestions: searchModel.searchSuggestions) { suggestion in
                                isFocused = false
                                performSearch(suggestion: suggestion)
                            }
                        }
                        if searchModel.isShowingOverseasResults {
                            OverseasResultsView(places: searchModel.overseasResults) { place in
                                choose(LocationTarget(name: place.name, subtitle: place.address,
                                    latitude: place.latitude, longitude: place.longitude))
                            }
                        }
                        if !searchModel.searchResults.isEmpty {
                            Text("Choose a place to add to the route")
                                .font(.subheadline).foregroundStyle(.secondary)
                            ForEach(searchModel.searchResults) { target in
                                Button { choose(target) } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(.blue).accessibilityHidden(true)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(target.name).foregroundStyle(.primary).font(.body.weight(.medium))
                                            if !target.subtitle.isEmpty {
                                                Text(target.subtitle).foregroundStyle(.secondary).font(.subheadline)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.blue).accessibilityHidden(true)
                                    }
                                    .padding(14)
                                    .frame(minHeight: 58)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Adds this place to the route")
                                .accessibilityIdentifier("routePlace.result")
                            }
                        }
                        if !searchModel.isSearching, !searchModel.isShowingSuggestions,
                           !searchModel.isShowingOverseasResults, searchModel.searchResults.isEmpty,
                           searchModel.errorMessage == nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Search for a place or address", systemImage: "magnifyingglass")
                                    .font(.headline)
                                Text("Enter a place name or address, then choose a result. You can also paste coordinates. Place search requires an internet connection.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(request.role.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("routePlace.cancel")
                }
            }
            .task {
                searchModel.searchRegion = request.region
                isFocused = true
            }
            .onDisappear {
                searchTask?.cancel()
                searchModel.clearSearch()
            }
        }
    }

    private func performSearch(suggestion: MapSearchSuggestion? = nil) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            if let suggestion { await searchModel.selectSuggestion(suggestion) }
            else { await searchModel.search() }
        }
    }

    private func choose(_ target: LocationTarget) {
        onSelect(target)
        dismiss()
    }
}
