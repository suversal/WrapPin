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
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .background(.regularMaterial, in: Capsule())
                Spacer(minLength: 8)
                if let coordinate {
                    let formatted = String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
                    Text(verbatim: formatted)
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityLabel("Crosshair coordinates")
                        .accessibilityValue(Text(verbatim: formatted))
                        .accessibilityIdentifier("map.precisionCoordinates")
                }
            }

            GeometryReader { geometry in
                if geometry.size.height >= 32 {
                    Image(systemName: "scope")
                        .font(.system(size: 23, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: Circle())
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
            Circle().fill(.regularMaterial)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.background, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                .offset(x: translation.width * scale, y: translation.height * scale)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
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
