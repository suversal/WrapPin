import SwiftUI

struct ConnectionBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption.weight(.semibold))

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("Connection status: %@", comment: ""),
                label
            )
        )
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
