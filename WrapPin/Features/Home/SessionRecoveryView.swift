import SwiftUI

struct SessionRecoveryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let recovery: SessionRecoveryRecord
    let isPaired: Bool
    let isResuming: Bool
    let isRestoring: Bool
    let errorMessage: String?
    let onResume: () -> Void
    let onRestore: () -> Void
    let onAlreadyRestored: () -> Void
    let onCancel: () -> Void

    @State private var isConfirmingRestore = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
                .frame(maxHeight: 540)
            } else {
                content
            }
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 26)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .liquidGlassSurface(
            in: RoundedRectangle(cornerRadius: 34, style: .continuous),
            prominentShadow: true
        )
        .confirmationDialog(
            "Restore this iPhone's real location?",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button("Restore Real Location", role: .destructive, action: onRestore)
            Button("Keep Recovery Options", role: .cancel) {}
        } message: {
            Text("WrapPin will reconnect only long enough to clear the simulated location. It will not start a new route session.")
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 66 : 78,
                        height: dynamicTypeSize.isAccessibilitySize ? 66 : 78
                    )

                Image(systemName: recovery.isRoute ? recovery.routeMode.symbol : "location.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 9) {
                Text("Previous Session Interrupted")
                    .font(.title2.bold())

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("This is the last location you set, not confirmation that it is still active.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                recoveryDetail(
                    title: recovery.isRoute
                        ? String(localized: "Last saved point")
                        : String(localized: "Last location"),
                    value: recovery.lastReportedLocation.name,
                    symbol: "mappin.and.ellipse"
                )

                if let destination = recovery.destination, recovery.isRoute {
                    recoveryDetail(
                        title: String(localized: "Destination"),
                        value: destination.name,
                        symbol: "flag.checkered"
                    )
                }

                recoveryDetail(
                    title: String(localized: "Last active"),
                    value: recovery.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    symbol: "clock"
                )
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if isResuming || isRestoring {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(
                        isRestoring
                            ? String(localized: "Restoring this iPhone's real location…")
                            : String(localized: "Resuming the previous session…")
                    )
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)

                Button(
                    isRestoring ? String(localized: "Cancel Restoration") : String(localized: "Cancel"),
                    role: .cancel, action: onCancel
                )
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onResume) {
                    Label(resumeTitle, systemImage: recovery.isRoute ? recovery.routeMode.symbol : "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .wrapPinPrimaryButton()
                .disabled(!isPaired)

                Button(role: .destructive) {
                    isConfirmingRestore = true
                } label: {
                    Label("Restore Real Location", systemImage: "location.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .wrapPinSecondaryButton(tint: .red)
                .disabled(!isPaired)

                Button("My Real Location Is Already Back", action: onAlreadyRestored)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !isPaired {
                Label("Pair this iPhone before resuming or restoring the session.", systemImage: "iphone.and.arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Restoring reconnects only long enough to clear the simulated location. Nothing starts automatically. Keep WrapPin open until it finishes.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryText: String {
        if let destination = recovery.destination, recovery.isRoute {
            let key = recovery.routeMode == .walking
                ? "WrapPin closed before it could confirm that the simulated walk to %@ ended. Continue from the last saved point or restore this iPhone's real location."
                : "WrapPin closed before it could confirm that the simulated drive to %@ ended. Continue from the last saved point or restore this iPhone's real location."
            return String(
                format: NSLocalizedString(
                    key,
                    comment: ""
                ),
                destination.name
            )
        }

        return String(
            format: NSLocalizedString(
                "WrapPin closed before it could confirm that the simulated location at %@ ended. Choose what this iPhone should do next.",
                comment: ""
            ),
            recovery.lastReportedLocation.name
        )
    }

    private var resumeTitle: String {
        if recovery.isRoute {
            return recovery.routeMode == .walking
                ? String(localized: "Resume Walking")
                : String(localized: "Resume Driving")
        }
        return String(localized: "Resume Location")
    }

    private func recoveryDetail(title: String, value: String, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.blue)
                        .frame(width: 22)

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
