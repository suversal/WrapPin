import MapKit
import SwiftUI

struct WalkingRoutePreviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: MKRoute
    let routes: [MKRoute]
    let selectedRouteIndex: Int
    let destination: LocationTarget
    let simulation: WalkingSimulationController
    let isPaired: Bool
    let onSelectRoute: (Int) -> Void
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onWalkBack: () -> Void
    let onChooseNewLocation: () -> Void
    let onStop: () -> Void
    let onDone: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent
                }
                .frame(maxHeight: 460)
            } else {
                cardContent
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        .overlay(alignment: .topTrailing) {
            if canClose {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close route preview")
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
        }
        .confirmationDialog(
            "Stop the route and restore this iPhone's real location?",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Stop & Restore", role: .destructive, action: onStop)
            Button("Keep Simulated Location", role: .cancel) {}
        } message: {
            Text("WrapPin will end the simulated route and restore your real location. Your route progress will be reset.")
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: phaseSymbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(phaseColour)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(phaseTitle)
                        .font(.headline)

                    Text(phaseSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                }

                Spacer(minLength: 0)

                if canClose {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
            }

            if showsProgress {
                ProgressView(value: simulation.progress)
                    .tint(simulation.phase == .arrived ? .green : .blue)
            }

            if canChoosePace, routes.count > 1 {
                routeOptions
            }

            routeMetrics

            if canChoosePace {
                if simulation.mode == .walking {
                    pacePicker
                } else {
                    drivingSpeedControl
                }
            }

            controls
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var pacePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Custom walking speed")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Toggle("Custom walking speed", isOn: customWalkingSpeedEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .fixedSize()
                    .scaleEffect(0.82, anchor: .trailing)
                    .frame(width: 56, height: 44, alignment: .trailing)
                    .accessibilityLabel("Custom walking speed")
            }
            .padding(.trailing, 4)
            if simulation.customWalkingSpeedKilometresPerHour != nil {
                HStack {
                    Text("Walking speed")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(customWalkingSpeedText)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
                Slider(value: customWalkingSpeedBinding, in: 1...12, step: 0.1)
                    .accessibilityLabel("Walking speed")
                    .accessibilityValue(customWalkingSpeedText)
                Text("Constant route speed · 1–12 km/h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if dynamicTypeSize.isAccessibilitySize {
                Picker("Walking pace", selection: paceBinding) {
                    ForEach(WalkingPace.allCases) { pace in
                        Text(pace.title).tag(pace)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Picker("Walking pace", selection: paceBinding) {
                    ForEach(WalkingPace.allCases) { pace in
                        Text(pace.title).tag(pace)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var drivingSpeedControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Simulated speed")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(drivingSpeedText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            Slider(value: drivingSpeedBinding, in: 5...240, step: 1)
                .accessibilityLabel("Simulated driving speed")
                .accessibilityValue(drivingSpeedText)
            Text("Constant route speed · 5–240 km/h")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var routeOptions: some View {
        let options = ForEach(Array(routes.enumerated()), id: \.offset) { index, option in
            routeOption(option, index: index)
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { options }
        } else {
            HStack(spacing: 8) { options }
        }
    }

    private func routeOption(_ option: MKRoute, index: Int) -> some View {
        let isSelected = index == selectedRouteIndex
        let duration = formatDuration(option.distance / simulation.speedMetresPerSecond)
        let distance = formatDistance(option.distance)

        return Button {
            onSelectRoute(index)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(duration)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .blue : .primary)
                Text(distance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !option.name.isEmpty {
                    Text(option.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? AnyShapeStyle(.blue.opacity(0.14)) : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.blue, lineWidth: isSelected ? 1.5 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("Route %lld, %@, %@", comment: ""),
                index + 1,
                duration,
                distance
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var routeMetrics: some View {
        let distance = RouteMetric(
            title: showsProgress ? String(localized: "Remaining") : String(localized: "Distance"),
            value: distanceText,
            symbol: "point.topleft.down.to.point.bottomright.curvepath"
        )
        let duration = RouteMetric(
            title: simulation.phase == .arrived ? String(localized: "Status") : String(localized: "Travel time"),
            value: durationText,
            symbol: simulation.phase == .arrived ? "checkmark.circle" : "clock"
        )
        let arrival = RouteMetric(
            title: String(localized: "Arrive"),
            value: simulation.phase == .paused ? String(localized: "Paused") : arrivalText,
            symbol: "flag.checkered"
        )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                distance
                duration
                arrival
            }
        } else {
            HStack(spacing: 10) {
                distance
                duration
                arrival
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch simulation.phase {
        case .idle:
            Button(action: onStart) {
                Label(
                    simulation.mode == .walking ? String(localized: "Start Walking") : String(localized: "Start Driving"),
                    systemImage: simulation.mode.symbol
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPaired)

        case .preparing:
            HStack(spacing: 10) {
                ProgressView()
                Text(simulation.mode == .walking
                     ? String(localized: "Starting walking session…")
                     : String(localized: "Starting driving session…"))
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)

        case .walking, .paused:
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        pauseButton
                        stopWalkingButton(showTitle: true)
                    }
                } else {
                    HStack(spacing: 10) {
                        pauseButton
                        stopWalkingButton(showTitle: false)
                    }
                }
            }

        case .arrived:
            if simulation.mode == .walking {
                Button(action: onWalkBack) {
                    Label("Walk Route Back", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        newLocationButton
                        stopAtArrivalButton(showTitle: true)
                    }
                } else {
                    HStack(spacing: 10) {
                        newLocationButton
                        stopAtArrivalButton(showTitle: false)
                    }
                }
            }

        case .stopping:
            HStack(spacing: 10) {
                ProgressView()
                Text("Restoring this iPhone's real location…")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)

        case .failed:
            Button(action: onStart) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPaired)
        }
    }

    private var pauseButton: some View {
                Button(action: onTogglePause) {
                    Label(
                        simulation.phase == .paused
                            ? String(localized: "Resume")
                            : String(localized: "Pause"),
                        systemImage: simulation.phase == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
    }

    @ViewBuilder
    private func stopWalkingButton(showTitle: Bool) -> some View {
                Button(role: .destructive) {
                    isConfirmingStop = true
                } label: {
            if showTitle {
                Label("Stop & Restore", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "stop.fill")
                    .frame(width: 28)
            }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Stop route and restore real location")
    }

    private var newLocationButton: some View {
        Button(action: onChooseNewLocation) {
            Label("New Location", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
        .buttonStyle(.bordered)
            .controlSize(.large)
    }

    @ViewBuilder
    private func stopAtArrivalButton(showTitle: Bool) -> some View {
                Button(role: .destructive) {
                    isConfirmingStop = true
                } label: {
            if showTitle {
                Label("Stop & Restore", systemImage: "location.slash.fill")
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "location.slash.fill")
                    .frame(width: 28)
            }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Stop and restore real location")
    }

    @ViewBuilder
    private var footer: some View {
        switch simulation.phase {
        case .idle:
            Text(
                isPaired
                    ? String(localized: "Your location will move along this route at the selected pace.")
                    : String(localized: "Pair this iPhone before starting a route session.")
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .preparing:
            Text("Follow the mobile-data guidance if it appears.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .walking:
            Text("Keep WrapPin running. You can use other apps while the route continues.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .paused:
            Text("Your simulated location will stay here until you resume the route.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .arrived:
            Text("The destination remains active until you stop and restore your real location.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .stopping:
            Text("Keep WrapPin open until the real location has been restored.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canClose: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var canChoosePace: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var showsProgress: Bool {
        switch simulation.phase {
        case .walking, .paused, .arrived:
            true
        case .idle, .preparing, .stopping, .failed:
            false
        }
    }

    private var phaseTitle: String {
        switch simulation.phase {
        case .idle: simulation.mode.title
        case .preparing: simulation.mode == .walking ? String(localized: "Preparing walk") : String(localized: "Preparing drive")
        case .walking: simulation.mode == .walking ? String(localized: "Walking") : String(localized: "Driving")
        case .paused: simulation.mode == .walking ? String(localized: "Walk paused") : String(localized: "Drive paused")
        case .arrived: String(localized: "Arrived")
        case .stopping: String(localized: "Ending route")
        case .failed: String(localized: "Route unavailable")
        }
    }

    private var phaseSubtitle: String {
        switch simulation.phase {
        case .idle, .preparing, .failed:
            String(
                format: NSLocalizedString("Current Location to %@", comment: ""),
                destination.name
            )
        case .walking, .paused:
            String(
                format: NSLocalizedString("Heading to %@ · %lld%%", comment: ""),
                destination.name,
                Int((simulation.progress * 100).rounded())
            )
        case .arrived:
            String(
                format: NSLocalizedString("Location active at %@", comment: ""),
                destination.name
            )
        case .stopping:
            String(localized: "Restoring this iPhone's real location")
        }
    }

    private var phaseSymbol: String {
        switch simulation.phase {
        case .idle, .preparing, .walking: simulation.mode.symbol
        case .paused: "pause.circle.fill"
        case .arrived: "checkmark.circle.fill"
        case .stopping: "location.slash.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColour: Color {
        switch simulation.phase {
        case .arrived: .green
        case .failed: .red
        case .idle, .preparing, .walking, .paused, .stopping: .blue
        }
    }

    private var paceBinding: Binding<WalkingPace> {
        Binding(
            get: { simulation.pace },
            set: { simulation.pace = $0 }
        )
    }

    private var customWalkingSpeedEnabled: Binding<Bool> {
        Binding(
            get: { simulation.customWalkingSpeedKilometresPerHour != nil },
            set: { simulation.customWalkingSpeedKilometresPerHour = $0 ? 5 : nil }
        )
    }

    private var customWalkingSpeedBinding: Binding<Double> {
        Binding(
            get: { simulation.customWalkingSpeedKilometresPerHour ?? 5 },
            set: { simulation.customWalkingSpeedKilometresPerHour = $0 }
        )
    }

    private var customWalkingSpeedText: String {
        String(
            format: NSLocalizedString("%.1f km/h", comment: ""),
            simulation.customWalkingSpeedKilometresPerHour ?? 5
        )
    }

    private var drivingSpeedBinding: Binding<Double> {
        Binding(
            get: { simulation.drivingSpeedKilometresPerHour },
            set: { simulation.drivingSpeedKilometresPerHour = $0 }
        )
    }

    private var drivingSpeedText: String {
        String(
            format: NSLocalizedString("%lld km/h", comment: ""),
            Int(simulation.drivingSpeedKilometresPerHour.rounded())
        )
    }

    private var distanceText: String {
        formatDistance(showsProgress ? simulation.remainingDistance : route.distance)
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if Locale.current.region?.identifier == "GB" {
            return formatUKDistance(distance)
        }

        let formatter = MeasurementFormatter()
        formatter.locale = .current
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: distance, unit: UnitLength.meters))
    }

    private func formatUKDistance(_ distance: CLLocationDistance) -> String {
        let metresPerMile = 1_609.344
        guard distance >= metresPerMile else {
            let yards = max(0, distance / 0.9144)
            return "\(Int(yards.rounded())) yd"
        }

        let miles = distance / metresPerMile
        return miles.formatted(
            .number.precision(.fractionLength(miles < 10 ? 1 : 0))
        ) + " mi"
    }

    private var durationText: String {
        guard simulation.phase != .arrived else { return String(localized: "Complete") }
        let duration = simulation.totalDistance > 0
            ? simulation.remainingDuration
            : route.distance / simulation.speedMetresPerSecond
        return formatDuration(duration)
    }

    private var arrivalText: String {
        guard simulation.phase != .arrived else { return String(localized: "Now") }
        let duration = simulation.totalDistance > 0
            ? simulation.remainingDuration
            : route.distance / simulation.speedMetresPerSecond
        return Date.now
            .addingTimeInterval(duration)
            .formatted(date: .omitted, time: .shortened)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        guard minutes >= 60 else {
            return String(
                format: NSLocalizedString("%lld min", comment: ""),
                minutes
            )
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0
            ? String(format: NSLocalizedString("%lld hr", comment: ""), hours)
            : String(
                format: NSLocalizedString("%lld hr %lld min", comment: ""),
                hours,
                remainingMinutes
            )
    }
}

private struct RouteMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
