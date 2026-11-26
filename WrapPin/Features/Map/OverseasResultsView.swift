import SwiftUI

/// Overseas search candidates. Results are never auto-selected: each shows how
/// precise it is, so a city-level answer is not mistaken for the exact address.
struct OverseasResultsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let places: [OverseasPlace]
    let onSelect: (OverseasPlace) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                Button {
                    onSelect(place)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: place.precision.isApproximate ? "mappin.and.ellipse" : "mappin.circle.fill")
                            .foregroundStyle(place.precision.isApproximate ? .orange : .blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                            if !place.address.isEmpty {
                                Text(place.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 8)

                        Text(precisionTitle(place.precision))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(place.precision.isApproximate ? .orange : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TactilePressButtonStyle(pressedScale: 0.985))
                .accessibilityLabel(accessibilityLabel(for: place))
                .accessibilityHint("Selects this location")

                Divider()
                    .padding(.leading, index < places.count - 1 ? 46 : 0)
            }

            attribution
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .liquidGlassSurface(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            prominentShadow: true
        )
    }

    // Required by the Geoapify free plan and the OpenStreetMap licence.
    private var attribution: some View {
        HStack(spacing: 4) {
            Text(verbatim: "Powered by")
            Link(destination: URL(string: "https://www.geoapify.com/")!) {
                Text(verbatim: "Geoapify")
            }
            Text(verbatim: "· ©")
            Link(destination: URL(string: "https://www.openstreetmap.org/copyright")!) {
                Text(verbatim: "OpenStreetMap")
            }
            Text(verbatim: "contributors")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 32)
        .padding(.horizontal, 14)
    }

    private func precisionTitle(_ precision: OverseasPlace.Precision) -> String {
        switch precision {
        case .building: String(localized: "House number")
        case .place: String(localized: "Place")
        case .street: String(localized: "Street")
        case .area: String(localized: "Area")
        case .city: String(localized: "City")
        case .region: String(localized: "Region")
        case .country: String(localized: "Country")
        case .unknown: String(localized: "Approximate")
        }
    }

    private func accessibilityLabel(for place: OverseasPlace) -> String {
        [place.name, place.address, precisionTitle(place.precision)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
