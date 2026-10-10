import CoreLocation
#if WRAPPIN_TUNNEL_EDITION
import NetworkExtension
#endif
import SwiftUI
import UIKit

struct ConnectionHealthView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var diagnostics = ConnectionDiagnosticsCoordinator()
    @State private var isShowingDeviceSetup = false
    @State private var didCopyDiagnostics = false
    @State private var probedTarget: LocationTarget?
    @State private var probedSimulationCoordinates: SimulationCoordinates?
    @State private var locationProbe = LocationAccuracyProbe()
#if WRAPPIN_TUNNEL_EDITION
    @StateObject private var builtInTunnel = BuiltInTunnelManager.shared
#endif

    var body: some View {
        List {
            Section("Connection Health") {
#if WRAPPIN_TUNNEL_EDITION
                if appModel.usesBuiltInTunnel {
                    healthRow(
                        title: String(localized: "Built-in VPN"),
                        value: builtInTunnelStatus,
                        symbol: builtInTunnel.status == .connected ? "checkmark.circle.fill" : "questionmark.circle",
                        color: builtInTunnel.status == .connected ? .green : .secondary
                    )
                }
#endif
                healthRow(
                    title: String(localized: "Pairing"),
                    value: pairingValue,
                    symbol: pairingSymbol,
                    color: pairingColor
                )

                healthRow(
                    title: String(localized: "Device Tunnel"),
                    value: localDevVPNValue,
                    symbol: localDevVPNSymbol,
                    color: localDevVPNColor
                )

                healthRow(
                    title: String(localized: "Location Session"),
                    value: sessionValue,
                    symbol: sessionSymbol,
                    color: sessionColor
                )

                healthRow(
                    title: String(localized: "Background Session"),
                    value: backgroundSessionValue,
                    symbol: backgroundSessionSymbol,
                    color: backgroundSessionColor
                )

                healthRow(
                    title: String(localized: "Connection Stage"),
                    value: appModel.deviceSession.connectionStage.title,
                    symbol: "point.3.connected.trianglepath.dotted",
                    color: sessionColor
                )

                if let endpointSource = appModel.deviceSession.endpointSource {
                    healthRow(
                        title: String(localized: "Device Address"),
                        value: endpointSource.title,
                        symbol: "network",
                        color: .secondary
                    )
                }

                if case .active = appModel.deviceSession.phase,
                   !appModel.deviceSession.backgroundKeepAlive.started {
                    Label(
                        "The current simulation can still work in the foreground, but background continuity is unavailable. Check Location access for WrapPin in Settings.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Restoration") {
                Text(appModel.deviceSession.restorationStatus)
                Text("An inactive session means WrapPin's worker has ended. Other apps may need time to acquire a fresh real location.")
                    .foregroundStyle(.secondary)
            }

            Section("Current Location") {
                LabeledContent("Place", value: activeTarget?.name ?? String(localized: "None"))
                LabeledContent("Coordinates", value: coordinatesValue)

                if let activeTarget, !activeTarget.subtitle.isEmpty {
                    LabeledContent("Area", value: activeTarget.subtitle)
                }
            }

            if let activeTarget {
                Section {
                    Button {
                        if locationProbe.isRunning {
                            locationProbe.stop()
                            probedTarget = nil
                            probedSimulationCoordinates = nil
                        } else {
                            probedTarget = activeTarget
                            probedSimulationCoordinates = appModel.deviceSession.activeSimulationCoordinates
                            locationProbe.start()
                        }
                    } label: {
                        Label(
                            locationProbe.isRunning ? "停止读取定位回调" : "读取原始定位回调",
                            systemImage: locationProbe.isRunning ? "stop.circle" : "location.magnifyingglass"
                        )
                    }

                    if let probedTarget, let probedSimulationCoordinates {
                        LabeledContent("地图选点", value: formattedCoordinates(
                            latitude: probedTarget.latitude,
                            longitude: probedTarget.longitude
                        ))
                        LabeledContent("模拟目标", value: formattedCoordinates(
                            latitude: probedSimulationCoordinates.latitude,
                            longitude: probedSimulationCoordinates.longitude
                        ))

                        if let sample = locationProbe.sample {
                            LabeledContent("定位回调", value: formattedCoordinates(
                                latitude: sample.latitude,
                                longitude: sample.longitude
                            ))
                            LabeledContent("数值距离", value: formattedDistance(
                                target: probedSimulationCoordinates,
                                sample: sample
                            ))
                            LabeledContent("水平精度", value: String(format: "%.0f m", sample.horizontalAccuracy))
                            LabeledContent("回调时间", value: sample.timestamp.formatted(
                                date: .omitted,
                                time: .standard
                            ))
                            LabeledContent("软件模拟标记", value: simulatedSourceValue(sample))
                        } else if let message = locationProbe.message {
                            Text(message)
                                .foregroundStyle(.orange)
                        } else {
                            Text("正在获取新的定位回调，最多等待 15 秒…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("定位精度调研")
                } footer: {
                    Text("使用独立定位读取器获取新的 Core Location 回调，关闭页面即清除。数值距离不能单独证明 Apple 地图蓝点的显示坐标。")
                }
            }

            Section {
                Button {
                    Task { await runConnectionCheck() }
                } label: {
                    HStack {
                        Label("Run Connection Check", systemImage: "stethoscope")
                        Spacer()
                        if diagnostics.state == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(diagnostics.state == .running)

                if let resultMessage {
                    Label(resultMessage, systemImage: resultSymbol)
                        .font(.subheadline)
                        .foregroundStyle(resultColor)
                }

                if let lastFailureMessage = appModel.deviceSession.lastFailureMessage {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Last session error", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(lastFailureMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Check the selected tunnel app, then run the connection check or try starting the location again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                if let lastChecked = diagnostics.lastChecked {
                    LabeledContent(
                        "Last checked",
                        value: lastChecked.formatted(date: .omitted, time: .shortened)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Connection Check")
            } footer: {
                Text("This checks the saved pairing record and whether the paired iPhone is reachable through a compatible device tunnel. It cannot inspect another app's VPN switch or change your location.")
            }

            Section {
                Button {
                    UIPasteboard.general.string = diagnosticsText
                    didCopyDiagnostics = true
                } label: {
                    Label(
                        didCopyDiagnostics ? "Diagnostics Copied" : "Copy Diagnostics",
                        systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc"
                    )
                }
                .foregroundStyle(didCopyDiagnostics ? .green : .primary)
            } header: {
                Text("Support")
            } footer: {
                Text("Copies a status-only report you can paste into a bug report. It never includes locations, searches, pairing records, PINs, device names or error text.")
            }

            Section("Other VPNs") {
                Text("Another VPN may affect local device connections. Keep a compatible device tunnel enabled when starting a location session; a regular proxy alone may not work.")
                if appModel.usesBuiltInTunnel {
                    Text("WrapPin uses its built-in device tunnel. If another VPN is active, stop it before testing this tunnel.")
                        .foregroundStyle(.secondary)
                } else if TunnelHandoffPolicy.recommendsWiFiWhenUnavailable(for: appModel.tunnelHandoffApp) {
                    Text(
                        String(
                            format: NSLocalizedString("%@ on mobile data may not expose the device connection WrapPin needs. Use Wi-Fi if the connection check fails.", comment: ""),
                            appModel.tunnelHandoffApp.title
                        )
                    )
                        .foregroundStyle(.secondary)
                }
            }

            Section("Help") {
                Button {
                    isShowingDeviceSetup = true
                } label: {
                    Label("Pairing & Connection", systemImage: "iphone.and.arrow.forward")
                }
                .foregroundStyle(.primary)

                if !appModel.usesBuiltInTunnel {
                    TunnelAppButton()
                }
            }
        }
        .navigationTitle("Connection Health")
        .navigationBarTitleDisplayMode(.inline)
#if WRAPPIN_TUNNEL_EDITION
        .task { await builtInTunnel.refresh() }
#endif
        .onDisappear {
            diagnostics.cancel()
            locationProbe.stop()
            probedTarget = nil
            probedSimulationCoordinates = nil
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
    }

    private var activeTarget: LocationTarget? {
        if case .active(let target) = appModel.deviceSession.phase {
            return target
        }
        return nil
    }

    private func formattedCoordinates(latitude: Double, longitude: Double) -> String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    private func formattedDistance(
        target: SimulationCoordinates,
        sample: LocationDiagnosticSample
    ) -> String {
        let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let receivedLocation = CLLocation(latitude: sample.latitude, longitude: sample.longitude)
        return String(format: "%.0f m", targetLocation.distance(from: receivedLocation))
    }

    private func simulatedSourceValue(_ sample: LocationDiagnosticSample) -> String {
        guard let isSimulated = sample.isSimulatedBySoftware else { return "未提供" }
        return isSimulated ? "是" : "否"
    }

    private var coordinatesValue: String {
        guard let activeTarget else { return String(localized: "None") }
        return String(format: "%.5f, %.5f", activeTarget.latitude, activeTarget.longitude)
    }

    private var pairingValue: String {
        switch appModel.pairingStatus {
        case .checking: String(localized: "Checking")
        case .importing: String(localized: "Importing")
        case .notPaired: String(localized: "Not paired")
        case .paired: String(localized: "Ready")
        case .failed: String(localized: "Problem")
        }
    }

    private var pairingSymbol: String {
        switch appModel.pairingStatus {
        case .checking, .importing: "arrow.triangle.2.circlepath"
        case .notPaired: "exclamationmark.circle"
        case .paired: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var pairingColor: Color {
        switch appModel.pairingStatus {
        case .checking, .importing: .blue
        case .notPaired: .orange
        case .paired: .green
        case .failed: .red
        }
    }

    private var localDevVPNValue: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return String(localized: "Connected") }
            return String(localized: "Not checked")
        case .running: return String(localized: "Checking")
        case .passed: return String(localized: "Reachable")
        case .failed: return String(localized: "Not reachable")
        }
    }

#if WRAPPIN_TUNNEL_EDITION
    private var builtInTunnelStatus: String {
        switch builtInTunnel.status {
        case .connected: String(localized: "Connected")
        case .connecting, .reasserting: String(localized: "Connecting")
        case .disconnecting: String(localized: "Disconnecting")
        case .disconnected, .invalid: String(localized: "Disconnected")
        @unknown default: String(localized: "Unknown")
        }
    }

    private var builtInTunnelErrorDetail: String { builtInTunnel.lastErrorDetail ?? "None" }
#else
    private var builtInTunnelStatus: String { "Not included" }
    private var builtInTunnelErrorDetail: String { "Not included" }
#endif

    private var localDevVPNSymbol: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "checkmark.circle.fill" }
            return "questionmark.circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var localDevVPNColor: Color {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return .green }
            return .secondary
        case .running: return .blue
        case .passed: return .green
        case .failed: return .red
        }
    }

    private var sessionValue: String {
        switch appModel.deviceSession.phase {
        case .idle: String(localized: "Inactive")
        case .openingLocalDevVPN: String(localized: "Opening tunnel app")
        case .discovering: String(localized: "Finding this iPhone")
        case .connecting: String(localized: "Connecting")
        case .active: String(localized: "Active")
        case .stopping: String(localized: "Stopping")
        case .failed: String(localized: "Failed")
        }
    }

    private var sessionSymbol: String {
        switch appModel.deviceSession.phase {
        case .idle: "pause.circle"
        case .openingLocalDevVPN, .discovering, .connecting: "arrow.triangle.2.circlepath"
        case .active: "location.circle.fill"
        case .stopping: "stop.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var sessionColor: Color {
        switch appModel.deviceSession.phase {
        case .idle: .secondary
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: .blue
        case .active: .green
        case .failed: .red
        }
    }

    private var backgroundSessionValue: String {
        appModel.deviceSession.backgroundKeepAlive.status.title
    }

    private var backgroundSessionSymbol: String {
        switch appModel.deviceSession.backgroundKeepAlive.status {
        case .receivingUpdates: "location.circle.fill"
        case .awaitingAuthorization, .starting: "arrow.triangle.2.circlepath"
        case .denied, .restricted, .servicesDisabled, .missingBackgroundMode, .failed:
            "exclamationmark.triangle.fill"
        case .locationUnavailable: "location.slash.circle"
        case .idle, .stopped: "pause.circle"
        }
    }

    private var backgroundSessionColor: Color {
        switch appModel.deviceSession.backgroundKeepAlive.status {
        case .receivingUpdates: .green
        case .awaitingAuthorization, .starting: .blue
        case .denied, .restricted, .servicesDisabled, .missingBackgroundMode, .failed: .orange
        case .locationUnavailable: .orange
        case .idle, .stopped: .secondary
        }
    }

    private var resultMessage: String? {
        switch diagnostics.state {
        case .notRun, .running: nil
        case .passed(let message), .failed(let message): message
        }
    }

    private var resultSymbol: String {
        switch diagnostics.state {
        case .passed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .notRun, .running: "circle"
        }
    }

    private var resultColor: Color {
        switch diagnostics.state {
        case .passed: .green
        case .failed: .red
        case .notRun, .running: .secondary
        }
    }

    private func healthRow(
        title: String,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                        Text(value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    Text(title)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    @MainActor
    private func runConnectionCheck() async {
        do {
            let pairingRecord = try await appModel.pairingService.pairingRecordData()
            diagnostics.run(
                pairingRecord: pairingRecord,
                sessionPhase: appModel.deviceSession.phase,
                tunnelHandoffApp: appModel.tunnelHandoffApp
            )
        } catch {
            diagnostics.run(
                pairingRecord: nil,
                sessionPhase: appModel.deviceSession.phase,
                tunnelHandoffApp: appModel.tunnelHandoffApp
            )
        }
    }

    private var diagnosticsText: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? String(localized: "Unknown")
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? String(localized: "Unknown")
        let checked = diagnostics.lastChecked?.formatted(date: .numeric, time: .standard)
            ?? String(localized: "Not run")

        return """
        WrapPin Diagnostics
        Generated: \(Date().formatted(date: .numeric, time: .standard))
        App: \(appVersion) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Pairing: \(pairingValue)
        Last pairing failure stage (this launch): \(appModel.onDevicePairing.lastFailureStage?.rawValue ?? "None")
        Device tunnel: \(localDevVPNValue)
        Tunnel source: \(appModel.usesBuiltInTunnel ? "Built-in" : appModel.tunnelHandoffApp.title)
        Built-in VPN: \(builtInTunnelStatus)
        Built-in VPN error: \(builtInTunnelErrorDetail)
        Session: \(sessionValue)
        Background session: \(appModel.deviceSession.backgroundKeepAlive.status.rawValue)
        Background session started: \(appModel.deviceSession.backgroundKeepAlive.started)
        Last session issue stage (this launch): \(appModel.deviceSession.lastFailureStage?.rawValue ?? "None")
        Last session issue disposition: \(appModel.deviceSession.lastFailureDisposition?.rawValue ?? "None")
        Restoration: \(appModel.deviceSession.restorationStatus)
        Last connection check: \(checked)
        Connection check result: \(diagnosticResultStatus)
        Appearance: \(appModel.appearance.title)
        Map style: \(appModel.mapDisplayStyle.title)
        Location data: Not included
        """
    }

    private var diagnosticResultStatus: String {
        switch diagnostics.state {
        case .notRun: "Not run"
        case .running: "Running"
        case .passed: "Passed"
        case .failed: "Failed"
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionHealthView()
            .environment(AppModel())
    }
}
