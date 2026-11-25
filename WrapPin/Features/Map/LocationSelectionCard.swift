import Foundation
import SwiftUI
import UIKit

struct LocationSelectionCard: View {
    @Environment(\.isEmbeddedMapPanel) private var isEmbeddedMapPanel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let location: LocationTarget?
    let isFavourite: Bool
    let isResolvingAddress: Bool
    let isPaired: Bool
    let sessionPhase: DeviceSessionPhase
    let tunnelHandoffApp: TunnelHandoffApp
    let usesBuiltInTunnel: Bool
    let tunnelAppInstallURL: URL
    let previewingRouteMode: RouteMode?
    let routeError: String?
    let coordinateMode: FixedCoordinateMode
    let recommendedCoordinateMode: FixedCoordinateMode
    @Binding var isCollapsed: Bool
    let onCoordinateModeChange: (FixedCoordinateMode) -> Void
    let onToggleFavourite: () -> Void
    let onClearSelection: () -> Void
    let onPreviewRoute: (RouteMode) -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    var onDockContentHeightChanged: ((CGFloat) -> Void)? = nil

    @State private var panelDrag: CGFloat = 0
    private var expansion: CGFloat { min(1, max(0, (isCollapsed ? 0 : 1) - panelDrag / 220)) }

    @State private var didCopyCoordinates = false
    @State private var isConfirmingStop = false
    @State private var dockHeaderHeight: CGFloat = 0
    @State private var dockDetailsHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if location != nil && !isEmbeddedMapPanel {
                MapPanelDisclosure(isCollapsed: $isCollapsed) { panelDrag = $0 }
            }
            if let location, let onDockContentHeightChanged {
                dockContent(for: location, onHeightChanged: onDockContentHeightChanged)
            } else {
                cardContent
                    .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, location == nil ? 16 : 0)
        .background {
            if !isEmbeddedMapPanel {
                Color.clear
                    .liquidGlassSurface(
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                        prominentShadow: true
                    )
            }
        }
        .sensoryFeedback(.selection, trigger: isCollapsed)
        .confirmationDialog(
            "Stop the simulated location and restore your real location?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop & Restore", role: .destructive, action: onStop)
            Button("Keep Simulated Location", role: .cancel) {}
        } message: {
            Text("WrapPin will end the simulated location and restore this iPhone's real location.")
        }
    }

    private func dockContent(
        for location: LocationTarget,
        onHeightChanged: @escaping (CGFloat) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            locationHeader(for: location)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 5)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { dockHeaderHeight = $0 }

            ScrollView {
                locationDetails
                    .padding(.top, 5)
                    .padding(.bottom, 12)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { dockDetailsHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("map.bottomCard")
        }
        .onChange(of: dockHeaderHeight + dockDetailsHeight, initial: true) { _, height in
            if height > 0 { onHeightChanged(height) }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let location {
            VStack(alignment: .leading, spacing: 16) {
                locationHeader(for: location)
                locationDetails
            }
        } else {
            HStack(spacing: 14) {
                Image(systemName: "hand.tap")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose a location")
                        .font(.headline)
                    Text("Search for a place, or tap the map to choose one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var locationDetails: some View {
        VStack(alignment: .leading, spacing: onDockContentHeightChanged == nil ? 16 : 10) {
            MapPanelDetails(progress: expansion) { coordinateModeSelection }

            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView().controlSize(.small).frame(width: 18, height: 18)
                    } else {
                        Image(systemName: primarySymbol)
                            .font(.system(size: 17, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text(primaryTitle)
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
            .wrapPinPrimaryButton(tint: isShowingActiveTarget ? .red : .blue)
            .disabled(isPrimaryDisabled)
            .animation(
                reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
                value: primaryTitle
            )
            .accessibilityIdentifier("map.primaryLocationAction")

            if canPreviewRoute {
                MapPanelDetails(progress: expansion) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) {
                            routePreviewButton(for: .walking)
                            routePreviewButton(for: .driving)
                        }
                    } else {
                        HStack(spacing: 8) {
                            routePreviewButton(for: .walking)
                            routePreviewButton(for: .driving)
                        }
                        .transition(detailTransition)
                    }
                }
            }

            if let routeError {
                Text(routeError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isActive && !isShowingActiveTarget {
                Button("Stop & Restore", role: .destructive) {
                    isConfirmingStop = true
                }
                .wrapPinSecondaryButton(tint: .red)
                .frame(maxWidth: .infinity)
            }

            MapPanelDetails(progress: isRoutineStatus ? expansion : 1) {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(isFailure ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            if shouldOfferTunnelApp {
                Link(destination: tunnelAppInstallURL) {
                    Label(
                        String(
                            format: NSLocalizedString("Get %@", comment: ""),
                            tunnelHandoffApp.title),
                        systemImage: "arrow.up.right.square"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // Details fade and settle from slightly below while the card resizes around them.
    private var detailTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 10)).combined(
                with: .scale(scale: 0.97, anchor: .top))
    }

    private var coordinateModeBinding: Binding<FixedCoordinateMode> {
        Binding(
            get: { coordinateMode },
            set: { onCoordinateModeChange($0) }
        )
    }

    private var coordinateModeSelection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Simulation coordinate mode")
                .font(.subheadline.weight(.semibold))

            Picker("Simulation coordinate mode", selection: coordinateModeBinding) {
                Text("GCJ-02 correction").tag(FixedCoordinateMode.gcj02)
                Text("WGS84 unchanged").tag(FixedCoordinateMode.wgs84)
            }
            .pickerStyle(.segmented)
            .disabled(isWorking)

            Text(
                recommendedCoordinateMode == .gcj02
                    ? String(
                        localized:
                            "For mainland China, try GCJ-02 first. If the position is off, switch to WGS84."
                    )
                    : String(
                        localized:
                            "Outside mainland China, try WGS84 first. If the position is off, switch to GCJ-02."
                    )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if isShowingActiveTarget {
                Text("Switching modes updates the current simulated location immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func routePreviewButton(for mode: RouteMode) -> some View {
        Button {
            onPreviewRoute(mode)
        } label: {
            HStack(spacing: 6) {
                if previewingRouteMode == mode {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: mode.symbol)
                }
                Text(
                    mode == .walking
                        ? String(localized: "Preview Walk") : String(localized: "Preview Drive")
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .wrapPinSecondaryButton()
        .disabled(isResolvingAddress || previewingRouteMode != nil)
    }

    @ViewBuilder
    private func locationHeader(for location: LocationTarget) -> some View {
        if dynamicTypeSize.isAccessibilitySize || isCollapsed {
            VStack(alignment: .leading, spacing: 6) {
                locationSummary(for: location)
                if !isCollapsed {
                    HStack(spacing: 4) {
                        Spacer()
                        locationActions
                    }
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                locationSummary(for: location)
                Spacer(minLength: 0)
                locationActions
            }
        }
    }

    private func locationSummary(for location: LocationTarget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)

                if isCollapsed {
                    Text(compactPhaseTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isActive ? .blue : .secondary)
                }

                if !isCollapsed {
                    Text(locationDescription(for: location))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)

                    Button {
                        copyCoordinates(for: location)
                    } label: {
                        Label(
                            didCopyCoordinates ? "Coordinates copied" : "Copy coordinates",
                            systemImage: didCopyCoordinates ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(didCopyCoordinates ? .green : .blue)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (didCopyCoordinates ? Color.green : Color.blue).opacity(0.12),
                            in: Capsule()
                        )
                        .frame(minHeight: 36, alignment: .leading)
                    }
                    .buttonStyle(TactilePressButtonStyle())
                    .sensoryFeedback(.success, trigger: didCopyCoordinates)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78),
                        value: didCopyCoordinates
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var locationActions: some View {
        Button(action: onToggleFavourite) {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isFavourite ? .pink : .secondary)
                .symbolEffect(.bounce, value: isFavourite)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(TactilePressButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isFavourite)
        .disabled(isResolvingAddress)
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")

        if canClearSelection {
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(TactilePressButtonStyle())
            .accessibilityLabel("Clear selected location")
        }
    }

    private func locationDescription(for location: LocationTarget) -> String {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return name }

        if subtitle.lowercased().hasPrefix(name.lowercased()) {
            let remainder = subtitle.dropFirst(name.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if !remainder.isEmpty {
                return remainder
            }
        }

        return subtitle
    }

    private func copyCoordinates(for location: LocationTarget) {
        UIPasteboard.general.string = String(
            format: "%.6f, %.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            location.latitude,
            location.longitude
        )
        didCopyCoordinates = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyCoordinates = false
        }
    }

    private var isActive: Bool {
        if case .active = sessionPhase { return true }
        return false
    }

    private var isShowingActiveTarget: Bool {
        guard
            let location,
            case .active(let activeTarget) = sessionPhase
        else { return false }
        return location.id == activeTarget.id
    }

    private var isWorking: Bool {
        switch sessionPhase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    private var isFailure: Bool {
        if case .failed = sessionPhase { return true }
        return false
    }

    private var compactPhaseTitle: String {
        switch sessionPhase {
        case .active: String(localized: "Location session active")
        case .stopping: String(localized: "Restoring real location")
        case .openingLocalDevVPN, .discovering, .connecting: String(localized: "Connecting…")
        case .failed: String(localized: "Connection failed")
        case .idle: isPaired ? String(localized: "Ready") : String(localized: "Pair this device")
        }
    }

    // Status copy that only repeats what the buttons already say; hidden while collapsed.
    private var isRoutineStatus: Bool {
        switch sessionPhase {
        case .idle:
            isPaired
        case .active:
            isShowingActiveTarget
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var shouldOfferTunnelApp: Bool {
        guard case .failed(let message) = sessionPhase else { return false }
        return message
            == String(
                localized:
                    "Could not open the selected tunnel app. Check that it is installed and supports app links."
            )
    }

    private var primaryTitle: String {
        switch sessionPhase {
        case .openingLocalDevVPN:
            usesBuiltInTunnel
                ? String(localized: "Starting built-in tunnel…")
                : String(
                    format: NSLocalizedString("Opening %@…", comment: ""), tunnelHandoffApp.title)
        case .discovering:
            String(localized: "Finding This iPhone…")
        case .connecting:
            String(localized: "Starting Location…")
        case .active:
            isShowingActiveTarget
                ? String(localized: "Stop & Restore")
                : String(localized: "Update Location")
        case .stopping:
            String(localized: "Restoring Real Location…")
        case .failed:
            String(localized: "Try Again")
        case .idle:
            String(localized: "Start Location")
        }
    }

    private var primarySymbol: String {
        switch sessionPhase {
        case .active: isShowingActiveTarget ? "stop.circle.fill" : "location.fill"
        case .failed: "arrow.clockwise"
        case .idle: "location.fill"
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: "hourglass"
        }
    }

    private var isPrimaryDisabled: Bool {
        isResolvingAddress || isWorking || (!isPaired && !isActive)
    }

    private var canClearSelection: Bool {
        switch sessionPhase {
        case .idle, .failed:
            true
        case .active:
            !isShowingActiveTarget
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            false
        }
    }

    private var canPreviewRoute: Bool {
        switch sessionPhase {
        case .idle, .active:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var statusMessage: String {
        switch sessionPhase {
        case .idle:
            return isPaired
                ? String(localized: "Start when ready. Stop restores this iPhone's real location.")
                : String(localized: "Pair this iPhone before starting location control.")
        case .openingLocalDevVPN:
            if usesBuiltInTunnel {
                return String(localized: "WrapPin is connecting its built-in device tunnel.")
            }
            return tunnelHandoffApp == .localDevVPN
                ? String(
                    localized:
                        "Wait for LocalDevVPN to connect and return. If it does not, return to WrapPin yourself."
                )
                : String(
                    localized: "Turn on the tunnel in the selected app, then return to WrapPin.")
        case .discovering:
            return String(localized: "Finding the paired iPhone through the private local tunnel.")
        case .connecting:
            return String(localized: "Opening the secure location session.")
        case .active(let target):
            if !isShowingActiveTarget, let location {
                return String(
                    format: NSLocalizedString(
                        "Currently using %@. Update to move to %@.", comment: ""),
                    target.name,
                    location.name
                )
            }
            return String(
                format: NSLocalizedString(
                    "This iPhone is using %@. Stop & Restore ends the simulation and restores its real location.",
                    comment: ""
                ),
                target.name
            )
        case .stopping:
            return String(
                localized:
                    "Restoring this iPhone's real location. Keep WrapPin open until this finishes.")
        case .failed(let message):
            return message
        }
    }

    private func primaryAction() {
        if isShowingActiveTarget {
            isConfirmingStop = true
        } else {
            onStart()
        }
    }
}
