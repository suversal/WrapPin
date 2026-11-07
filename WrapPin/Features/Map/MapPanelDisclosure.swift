import SwiftUI

/// A visible button and a drag handle share the same disclosure state.
/// Keep the gesture on this header so sliders and scrolling remain independent.
struct MapPanelDisclosure: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            setCollapsed(!isCollapsed)
        } label: {
            HStack(spacing: 12) {
                Capsule()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 32, height: 4)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                Text(isCollapsed ? "Show Details" : "Hide Details")
                    .font(.caption.weight(.semibold))
                Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("map.detailsDisclosure")
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let vertical = value.translation.height
                    guard abs(vertical) > 35, abs(vertical) > abs(value.translation.width) * 1.3
                    else {
                        return
                    }
                    setCollapsed(vertical > 0)
                }
        )
    }

    private func setCollapsed(_ collapsed: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.88)) {
            isCollapsed = collapsed
        }
    }
}

/// Fit short cards to their content and scroll tall cards within the safe area.
/// Measuring the content avoids a tall fitting container centering a short card.
struct MapPanelViewport<Content: View>: View {
    let maximumHeight: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat?

    var body: some View {
        ScrollView(.vertical) {
            content()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(contentHeight ?? maximumHeight, maximumHeight), alignment: .bottom)
    }
}
