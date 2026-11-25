import SwiftUI

struct RestoringRealLocationCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(.blue)

            Text("Location Simulation Stopped")
                .font(.headline)

            Text("Waiting for a fresh location from this iPhone. Other apps may also take time to update…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .liquidGlassSurface(
            in: RoundedRectangle(cornerRadius: 24, style: .continuous),
            prominentShadow: true
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Location simulation stopped. Waiting for a fresh location from this iPhone.")
    }
}
