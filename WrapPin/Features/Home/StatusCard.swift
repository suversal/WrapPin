import SwiftUI

struct StatusCard: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .liquidGlassSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch state {
        case .notConfigured: String(localized: "Not configured")
        case .ready: String(localized: "Ready")
        case .connecting: String(localized: "Connecting")
        case .active: String(localized: "Location session active")
        case .failed: String(localized: "Connection error")
        }
    }

    private var detail: String {
        switch state {
        case .notConfigured: String(localized: "Pairing support has not been added yet.")
        case .ready: String(localized: "The paired device is available.")
        case .connecting: String(localized: "WrapPin is preparing the secure device session.")
        case .active: String(localized: "WrapPin is controlling the session.")
        case .failed(let message): message
        }
    }

    private var iconName: String {
        switch state {
        case .notConfigured: "circle.dashed"
        case .ready: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .active: "location.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .notConfigured: .secondary
        case .ready: .green
        case .connecting: .blue
        case .active: .blue
        case .failed: .red
        }
    }
}
