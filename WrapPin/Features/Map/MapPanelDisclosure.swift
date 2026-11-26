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
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84)) { isCollapsed = collapsed }
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
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .modifier(HiddenScrollEdgeEffectModifier())
        .frame(height: min(contentHeight ?? maximumHeight, maximumHeight), alignment: .top)
    }
}

private struct HiddenScrollEdgeEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectHidden(true, for: .all)
        } else {
            content
        }
    }
}

/// Native-like velocity-aware detent snapping and rubber-band resistance for map docks.
enum DockDetentPhysics {
    static func rubberBandedHeight(raw: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        if raw < minimum {
            let overscroll = minimum - raw
            return minimum - (overscroll * 0.22) / (1 + overscroll / 120)
        } else if raw > maximum {
            let overscroll = raw - maximum
            return maximum + (overscroll * 0.22) / (1 + overscroll / 120)
        }
        return raw
    }

    static func targetDetentIndex(
        currentIndex: Int,
        heights: [CGFloat],
        translation: CGFloat,
        predictedTranslation: CGFloat
    ) -> Int {
        guard heights.indices.contains(currentIndex) else { return currentIndex }
        let projectedHeight = heights[currentIndex] - predictedTranslation
        // Find the detent closest to the momentum-projected height.
        var bestIndex = currentIndex
        var bestDistance = abs(heights[currentIndex] - projectedHeight)
        for index in heights.indices {
            let distance = abs(heights[index] - projectedHeight)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        // If a deliberate flick didn't cross midpoint, still step one detent in flick direction.
        if bestIndex == currentIndex {
            let velocityDelta = predictedTranslation - translation
            if velocityDelta < -80 || translation < -44 {
                bestIndex = min(heights.count - 1, currentIndex + 1)
            } else if velocityDelta > 80 || translation > 44 {
                bestIndex = max(0, currentIndex - 1)
            }
        }
        return bestIndex
    }
}

/// Consistent floating Liquid Glass panel across all detents.
struct MapFloatingPanelBackground: View {
    let isExpanded: Bool

    var body: some View {
        Color.clear
            .liquidGlassSurface(
                in: RoundedRectangle(cornerRadius: 32, style: .continuous),
                prominentShadow: true
            )
    }
}

private struct EmbeddedMapPanelKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isEmbeddedMapPanel: Bool {
        get { self[EmbeddedMapPanelKey.self] }
        set { self[EmbeddedMapPanelKey.self] = newValue }
    }
}
