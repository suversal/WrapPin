import SwiftUI

struct MapSearchBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var symbolSize = 17
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let isSearching: Bool
    /// Nil when this build has no overseas search service configured.
    var isOverseasSearch: Bool?
    var onToggleOverseasSearch: () -> Void = {}
    let onSubmit: () -> Void
    let onClear: () -> Void
    var fieldIdentifier: String = "map.searchField"

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    searchFieldRow

                    if isOverseasSearch != nil || isFocused {
                        Divider()
                        HStack {
                            searchScopeButton
                            Spacer(minLength: 0)
                            if isFocused {
                                dismissKeyboardButton
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    searchFieldRow

                    if isFocused {
                        Divider()
                            .frame(height: 22)
                            .transition(.opacity)
                        dismissKeyboardButton
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 4)
        .frame(minHeight: 52)
        .liquidGlassSurface(
            in: RoundedRectangle(
                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 24 : 26,
                style: .continuous
            ),
            interactive: true
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
            value: isFocused
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82),
            value: query.isEmpty
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82),
            value: isOverseasSearch
        )
    }

    private var searchFieldRow: some View {
        HStack(spacing: 10) {
            Image(systemName: isOverseasSearch == true ? "globe.asia.australia.fill" : "magnifyingglass")
                .font(.system(size: min(symbolSize, 24), weight: .medium))
                .foregroundStyle(isOverseasSearch == true ? AnyShapeStyle(.blue) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)

            TextField(
                isOverseasSearch == true
                    ? LocalizedStringKey("Search overseas places or coordinates")
                    : LocalizedStringKey("Search places or coordinates"),
                text: $query
            )
                .font(.body)
                .focused($isFocused)
                .accessibilityIdentifier(fieldIdentifier)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    isFocused = false
                    onSubmit()
                }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            } else if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: min(symbolSize, 24)))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(TactilePressButtonStyle())
                .accessibilityLabel("Clear search")
                .transition(reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity))
            }

            if !dynamicTypeSize.isAccessibilitySize {
                searchScopeButton
            }
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var searchScopeButton: some View {
        if let isOverseasSearch {
            Button(action: onToggleOverseasSearch) {
                Text(isOverseasSearch ? "Overseas" : "Domestic")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOverseasSearch ? .white : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isOverseasSearch ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.quaternary),
                        in: Capsule()
                    )
                    .frame(minHeight: 44)
            }
            .buttonStyle(TactilePressButtonStyle())
            .sensoryFeedback(.selection, trigger: isOverseasSearch)
            .accessibilityLabel("Overseas search")
            .accessibilityHint("Switches between domestic and overseas place search")
            .accessibilityAddTraits(isOverseasSearch ? .isSelected : [])
        }
    }

    private var dismissKeyboardButton: some View {
        Button("Done") {
            isFocused = false
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.blue)
        .buttonStyle(TactilePressButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Dismiss keyboard")
        .accessibilityHint("Dismisses the keyboard")
    }
}
