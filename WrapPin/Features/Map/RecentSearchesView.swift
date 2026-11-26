import SwiftUI

struct RecentSearchesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let queries: [String]
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent searches")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Clear", action: onClearAll)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .buttonStyle(TactilePressButtonStyle())
                    .accessibilityLabel("Clear recent searches")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ForEach(Array(queries.enumerated()), id: \.element) { index, query in
                HStack(spacing: 0) {
                    Button {
                        onSelect(query)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            Text(query)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                            Spacer(minLength: 8)
                        }
                        .padding(.leading, 14)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TactilePressButtonStyle(pressedScale: 0.985))
                    .accessibilityHint("Searches for this place again")

                    Button {
                        onRemove(query)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(TactilePressButtonStyle())
                    .accessibilityLabel("Remove recent search")
                }

                if index < queries.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .liquidGlassSurface(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            prominentShadow: true
        )
    }
}
