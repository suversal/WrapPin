import MapKit
import SwiftUI

struct PrecisionMapPicker: View {
    static let mapSpace = "home.map"

    let camera: MapCamera?
    let coordinateAtPoint: (CGPoint) -> CLLocationCoordinate2D?
    let onMove: (CGSize) -> Void
    let onConfirm: (CLLocationCoordinate2D) -> Void
    let onCancel: () -> Void

    @State private var reticlePoint: CGPoint?

    var body: some View {
        let coordinate = pointUnderReticle
        VStack(spacing: 8) {
            LiquidGlassContainer(spacing: 10) {
                HStack {
                    Button("Cancel", action: onCancel)
                        .wrapPinSecondaryButton()
                    Spacer(minLength: 8)
                    if let coordinate {
                        let formatted = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
                        Text(verbatim: formatted)
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .liquidGlassSurface(in: Capsule())
                            .accessibilityLabel("Crosshair coordinates")
                            .accessibilityValue(Text(verbatim: formatted))
                            .accessibilityIdentifier("map.precisionCoordinates")
                    }
                }
            }

            GeometryReader { geometry in
                if geometry.size.height >= 32 {
                    ZStack {
                        Image(systemName: "scope")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .liquidGlassSurface(in: Circle())
                        Circle()
                            .fill(.blue)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onGeometryChange(for: CGPoint?.self) { geometry in
                let frame = geometry.frame(in: .named(Self.mapSpace))
                guard frame.height >= 32 else { return nil }
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { point in
                reticlePoint = point
            }

            HStack {
                MapNudgeControl(onMove: onMove)
                Spacer(minLength: 12)
                Button("Confirm selection") {
                    guard let coordinate = pointUnderReticle else { return }
                    onConfirm(coordinate)
                }
                .wrapPinPrimaryButton()
                .disabled(coordinate == nil)
                .accessibilityIdentifier("map.confirmPrecisionSelection")
            }
        }
        .padding(16)
    }

    private var pointUnderReticle: CLLocationCoordinate2D? {
        guard camera != nil, let reticlePoint, let coordinate = coordinateAtPoint(reticlePoint),
            CLLocationCoordinate2DIsValid(coordinate)
        else { return nil }
        return coordinate
    }
}

private struct MapNudgeControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let onMove: (CGSize) -> Void

    @GestureState private var isDragging = false
    @State private var translation = CGSize.zero
    private let diameter: CGFloat = 84
    private let radius: CGFloat = 24
    private let deadZone: CGFloat = 3

    private var deflectionDistance: CGFloat {
        hypot(translation.width, translation.height)
    }

    private var isNudging: Bool {
        deflectionDistance > deadZone
    }

    var body: some View {
        let scale = radius / max(radius, deflectionDistance)
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.28 : 0.70),
                                    .white.opacity(colorScheme == .dark ? 0.08 : 0.18),
                                    .black.opacity(colorScheme == .dark ? 0.24 : 0.06),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
                        .padding(10)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.14), radius: 14, y: 6)

            // Cardinal direction dots make the precision track immediately legible.
            Group {
                Circle().frame(width: 3.5, height: 3.5).offset(y: -31)
                Circle().frame(width: 3.5, height: 3.5).offset(y: 31)
                Circle().frame(width: 3.5, height: 3.5).offset(x: -31)
                Circle().frame(width: 3.5, height: 3.5).offset(x: 31)
            }
            .foregroundStyle(.secondary.opacity(0.55))

            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isNudging ? .blue : .primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            isNudging
                                ? Color.blue.opacity(0.55)
                                : .white.opacity(colorScheme == .dark ? 0.22 : 0.65),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                .offset(x: translation.width * scale, y: translation.height * scale)
                .animation(
                    reduceMotion || isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.68),
                    value: translation
                )
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .sensoryFeedback(.impact(weight: .light), trigger: isNudging)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragging) { _, dragging, _ in dragging = true }
                .onChanged { value in
                    let wasNudging = isNudging
                    translation = CGSize(
                        width: value.location.x - diameter / 2,
                        height: value.location.y - diameter / 2
                    )
                    if !wasNudging { move(for: 0.032) }
                }
                .onEnded { _ in translation = .zero }
        )
        .onChange(of: isDragging) { _, dragging in
            if !dragging { translation = .zero }
        }
        .task(id: isNudging) {
            if isNudging { await moveWhileDragging() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map joystick")
        .accessibilityIdentifier("map.precisionJoystick")
        .accessibilityAction(named: Text("Move up")) { onMove(CGSize(width: 0, height: -12)) }
        .accessibilityAction(named: Text("Move down")) { onMove(CGSize(width: 0, height: 12)) }
        .accessibilityAction(named: Text("Move left")) { onMove(CGSize(width: -12, height: 0)) }
        .accessibilityAction(named: Text("Move right")) { onMove(CGSize(width: 12, height: 0)) }
    }

    @MainActor
    private func moveWhileDragging() async {
        var lastTick = ProcessInfo.processInfo.systemUptime
        while !Task.isCancelled {
            do { try await Task.sleep(for: .milliseconds(32)) }
            catch { return }
            guard !Task.isCancelled, isNudging else { return }

            let now = ProcessInfo.processInfo.systemUptime
            move(for: min(now - lastTick, 0.064))
            lastTick = now
        }
    }

    private func move(for elapsed: TimeInterval) {
        let distance = deflectionDistance
        guard distance > deadZone else { return }
        let deflection = min(1, (distance - deadZone) / (radius - deadZone))
        let speed = deflection * (36 + 144 * deflection)
        let step = speed * elapsed / distance
        onMove(CGSize(width: translation.width * step, height: translation.height * step))
    }
}
