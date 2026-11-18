import SwiftUI

/// Only the handle owns the drag; card buttons and scrolling remain independent.
struct MapPanelDisclosure: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isCollapsed: Bool
    var onDragChanged: (CGFloat) -> Void = { _ in }
    @GestureState private var translation: CGFloat = 0

    var body: some View {
        Capsule().fill(.secondary.opacity(0.4)).frame(width: 36, height: 5)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($translation) { value, state, _ in
                    if abs(value.translation.height) > abs(value.translation.width) { state = value.translation.height }
                }
                .onEnded { value in
                    guard abs(value.translation.height) > 36,
                          abs(value.translation.height) > abs(value.translation.width) else { return }
                    setCollapsed(value.translation.height > 0)
                })
            .onChange(of: translation) { _, value in onDragChanged(value) }
            .accessibilityElement()
            .accessibilityLabel("Route panel handle")
            .accessibilityValue(isCollapsed ? String(localized: "Show Details") : String(localized: "Hide Details"))
            .accessibilityIdentifier("map.detailsDisclosure")
            .accessibilityAction(named: Text("Show Details")) { setCollapsed(false) }
            .accessibilityAction(named: Text("Hide Details")) { setCollapsed(true) }
    }

    private func setCollapsed(_ collapsed: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { isCollapsed = collapsed }
    }
}

/// Keep a single instance of details and reveal their measured height during a drag.
struct MapPanelDetails<Content: View>: View {
    let progress: CGFloat
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        content()
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            .frame(height: contentHeight * progress, alignment: .top)
            .opacity(progress)
            .clipped()
            .allowsHitTesting(progress > 0.95)
            .accessibilityHidden(progress < 0.95)
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

/// Blur map detail behind text; full-height panels use an opaque reading surface.
struct MapFloatingPanelBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let isExpanded: Bool

    var body: some View {
        if isExpanded {
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
                .fill(Color(uiColor: .systemBackground))
                .ignoresSafeArea(.container, edges: .bottom)
        } else if reduceTransparency {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        } else {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(uiColor: .systemBackground).opacity(0.16))
                }
        }
    }
}

private struct EmbeddedMapPanelKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isEmbeddedMapPanel: Bool {
        get { self[EmbeddedMapPanelKey.self] }
        set { self[EmbeddedMapPanelKey.self] = newValue }
    }
}
