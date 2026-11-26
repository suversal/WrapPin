import SwiftUI

struct ConnectionBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                LivePulseRing(color: color, diameter: 10, isActive: isLive)
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 12, height: 12)

            Text(label)
                .font(.caption.weight(.semibold))
                .contentTransition(.opacity)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .liquidGlassControl(in: Capsule())
        .animation(
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
            value: label
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("Connection status: %@", comment: ""),
                label
            )
        )
    }

    private var isLive: Bool {
        switch state {
        case .connecting, .active: true
        case .notConfigured, .ready, .failed: false
        }
    }

    private var label: String {
        switch state {
        case .notConfigured: String(localized: "Set up device")
        case .ready: String(localized: "Ready")
        case .connecting: String(localized: "Connecting…")
        case .active: String(localized: "Session active")
        case .failed: String(localized: "Connection error")
        }
    }

    private var color: Color {
        switch state {
        case .notConfigured: .orange
        case .ready: .green
        case .connecting: .blue
        case .active: .blue
        case .failed: .red
        }
    }
}
