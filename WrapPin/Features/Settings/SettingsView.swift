import SwiftUI

struct SettingsView: View {
    private static let repositoryURL = URL(
        string: "https://github.com/suversal/WrapPin"
    )!
    private static let bugReportURL = URL(
        string: "https://github.com/suversal/WrapPin/issues/new?template=bug_report.yml"
    )!
    private static let featureRequestURL = URL(
        string: "https://github.com/suversal/WrapPin/issues/new?template=feature_request.yml"
    )!
    private static let xProfileURL = URL(
        string: "https://x.com/suversal"
    )!

    @Environment(AppModel.self) private var appModel
    @Environment(ReleaseUpdateModel.self) private var releaseUpdates
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var xLogoSize: CGFloat = 25
    @State private var isShowingDeviceSetup = false
    @State private var isReplayingOnboarding = false
    @State private var isConfirmingReset = false
    @State private var resetError: String?
#if WRAPPIN_TUNNEL_EDITION
    @StateObject private var builtInTunnel = BuiltInTunnelManager.shared
#endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsRowLabel("Theme", symbol: "paintpalette")
                            .font(.subheadline.weight(.medium))

                        themePicker
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        settingsRowLabel("Map Style", symbol: "map")
                            .font(.subheadline.weight(.medium))

                        mapStylePicker
                    }
                    .padding(.vertical, 4)
                }

                Section("Device") {
                    NavigationLink {
                        ConnectionHealthView()
                            .environment(appModel)
                    } label: {
                        settingsRowLabel("Connection Health", symbol: "stethoscope")
                    }

                    Button {
                        isShowingDeviceSetup = true
                    } label: {
                        Label {
                            pairingConnectionLabel
                        } icon: {
                            settingsRowIcon("iphone.and.arrow.forward")
                        }
                    }
                    .foregroundStyle(.primary)

#if WRAPPIN_TUNNEL_EDITION
                    NavigationLink {
                        BuiltInTunnelSettingsView()
                            .environment(appModel)
                    } label: {
                        HStack {
                            settingsRowLabel("Built-in Tunnel", symbol: "network")
                            Spacer()
                            Text(builtInTunnelStatus)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .task { await builtInTunnel.refresh() }
#endif
                }

                if !appModel.usesBuiltInTunnel {
                    Section {
                        Picker(selection: tunnelHandoffAppBinding) {
                            ForEach(TunnelHandoffApp.allCases) { app in
                                Text(app.title).tag(app)
                            }
                        } label: {
                            settingsRowLabel("Tunnel App", symbol: "network")
                        }
                        .accessibilityHint("Selects the app to open when WrapPin cannot reach the paired iPhone.")
                    } footer: {
                        switch appModel.tunnelHandoffApp {
                        case .localDevVPN:
                            Text("On Wi-Fi, WrapPin opens LocalDevVPN if the paired iPhone is unreachable. On mobile data, it uses LocalDevVPN's connect-and-return flow before continuing. If it does not return automatically, check its tunnel and come back to WrapPin.")
                        case .shadowrocket:
                            Text("WrapPin asks Shadowrocket to connect its VPN only when it cannot find the paired iPhone's device connection. Shadowrocket requires Include Route 10.7.0.1/32 turned on in its Settings. If mobile data fails, use Wi-Fi. WrapPin cannot inspect Shadowrocket's VPN switch.")
                        case .surge:
                            Text("WrapPin asks Surge to start its selected configuration only when it cannot find the paired iPhone's device connection. Surge 5.23+ requires 10.7.0.1/32 in tun-included-routes and 10.7.0.1 = reflect in IP Rewrite. If mobile data fails, use Wi-Fi. WrapPin cannot inspect Surge's VPN switch.")
                        case .loon:
                            Text("WrapPin asks Loon to turn on its VPN only when it cannot find the paired iPhone's device connection. Loon build 1007+ requires include-tun = 10.7.0.1/32 and an enabled plugin with 10.7.0.1 = reflect in IP Rewrite. If mobile data fails, use Wi-Fi. WrapPin cannot inspect Loon's VPN switch.")
                        }
                    }
                }

                Section {
                    Toggle(isOn: anonymousUsageStatisticsBinding) {
                        settingsRowLabel("Share Anonymous Usage Statistics", symbol: "chart.bar")
                    }

                    NavigationLink {
                        UsageStatisticsPrivacyView()
                    } label: {
                        settingsRowLabel("What Is Shared", symbol: "hand.raised")
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Optional and off by default. Helps estimate activity from participating installations. Locations, searches and pairing data are never included.")
                }

                Section("About") {
                    NavigationLink {
                        AboutWrapPinView()
                    } label: {
                        settingsRowLabel("About WrapPin", symbol: "info.circle")
                    }

                    LabeledContent {
                        Text(versionText)
                    } label: {
                        settingsRowLabel("Version", symbol: "tag")
                    }
                    LabeledContent {
                        Text(buildNumberText)
                    } label: {
                        settingsRowLabel("Build", symbol: "hammer")
                    }
                    LabeledContent {
                        Text(buildDateText)
                    } label: {
                        settingsRowLabel("Built", symbol: "calendar")
                    }

                    Button {
                        isReplayingOnboarding = true
                    } label: {
                        settingsRowLabel("Replay Introduction", symbol: "sparkles")
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        Task { await releaseUpdates.checkForUpdates() }
                    } label: {
                        Label {
                            Text(updateCheckTitle)
                        } icon: {
                            settingsRowIcon(updateCheckSymbol)
                        }
                    }
                    .disabled(releaseUpdates.status == .checking)

                    updateStatusDetail
                } header: {
                    Text("Updates")
                } footer: {
                    Text("WrapPin checks the latest public GitHub release when it opens. You can check again here. Location, pairing and diagnostic data are not sent with this request.")
                }

                Section {
                    Link(destination: Self.repositoryURL) {
                        settingsRowLabel("View & Star on GitHub", symbol: "star")
                    }

                    Link(destination: Self.bugReportURL) {
                        settingsRowLabel("Report a Bug", symbol: "ladybug")
                    }

                    Link(destination: Self.featureRequestURL) {
                        settingsRowLabel("Request a Feature", symbol: "lightbulb")
                    }

                    Link(destination: Self.xProfileURL) {
                        Label {
                            Text("Follow Me")
                        } icon: {
                            Text(verbatim: "𝕏")
                                .font(.system(size: xLogoSize, weight: .regular))
                                .frame(width: 24, height: xLogoSize)
                                .accessibilityHidden(true)
                        }
                    }
                } header: {
                    Text("Community")
                } footer: {
                    Text("Star the repository if WrapPin helps you, or suggest an improvement. For pairing or connection problems, open Connection Health and use Copy Diagnostics. Never include pairing records, credentials or private locations.")
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        settingsRowLabel("Reset WrapPin", symbol: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("This clears the pairing record and local app settings, then shows onboarding again. VPN configurations remain in iOS Settings.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
        .fullScreenCover(isPresented: $isReplayingOnboarding) {
            OnboardingView(isReplay: true)
                .environment(appModel)
        }
        .confirmationDialog(
            "Reset WrapPin?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset App", role: .destructive) {
                Task { await resetApp() }
            }
        } message: {
            Text("Your pairing record and local choices will be removed. You will return to the welcome screen.")
        }
        .alert("Reset could not finish", isPresented: isShowingResetError) {
            Button("OK", role: .cancel) {
                resetError = nil
            }
        } message: {
            Text(resetError ?? String(localized: "Please try again."))
        }
    }

    private var connectionLabel: String {
        switch appModel.connectionState {
        case .notConfigured: String(localized: "Not paired")
        case .ready: String(localized: "Ready")
        case .connecting: String(localized: "Connecting")
        case .active: String(localized: "Active")
        case .failed: String(localized: "Problem")
        }
    }

    private func settingsRowLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label {
            Text(title)
        } icon: {
            settingsRowIcon(symbol)
        }
    }

    private func settingsRowIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.body)
            .frame(width: 24)
            .accessibilityHidden(true)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appModel.appearance {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { appModel.appearance },
            set: appModel.setAppearance
        )
    }

    @ViewBuilder
    private var themePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Theme", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Theme", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage)
                        .tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var mapStylePicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Map Style", selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Map Style", selection: mapStyleBinding) {
                ForEach(MapDisplayStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var pairingConnectionLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                Text("Pairing & Connection")
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text("Pairing & Connection")
                Spacer()
                Text(connectionLabel)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var mapStyleBinding: Binding<MapDisplayStyle> {
        Binding(
            get: { appModel.mapDisplayStyle },
            set: appModel.setMapDisplayStyle
        )
    }

    private var tunnelHandoffAppBinding: Binding<TunnelHandoffApp> {
        Binding(
            get: { appModel.tunnelHandoffApp },
            set: appModel.setTunnelHandoffApp
        )
    }

#if WRAPPIN_TUNNEL_EDITION
    private var builtInTunnelStatus: String {
        if builtInTunnel.isStarting { return String(localized: "Connecting") }
        if builtInTunnel.hasConfiguration && !builtInTunnel.isConfigurationEnabled {
            return String(localized: "VPN Configuration Disabled")
        }
        switch builtInTunnel.status {
        case .connected: return String(localized: "Connected")
        case .connecting, .reasserting: return String(localized: "Connecting")
        case .disconnecting: return String(localized: "Disconnecting")
        case .disconnected, .invalid: return String(localized: "Disconnected")
        @unknown default: return String(localized: "Unknown")
        }
    }
#endif

    private var anonymousUsageStatisticsBinding: Binding<Bool> {
        Binding(
            get: { appModel.sharesAnonymousUsageStatistics },
            set: appModel.setSharesAnonymousUsageStatistics
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }

    private var buildNumberText: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build ?? "Unknown"
    }

    private var buildDateText: String {
        if
            let timestamp = Bundle.main.object(
                forInfoDictionaryKey: "WrapPinBuildTimestamp"
            ) as? String,
            let buildDate = ISO8601DateFormatter().date(from: timestamp)
        {
            return buildDate.formatted(date: .abbreviated, time: .shortened)
        }

        guard
            let executableURL = Bundle.main.executableURL,
            let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]),
            let buildDate = values.contentModificationDate
        else { return String(localized: "Unknown") }

        return buildDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var updateCheckTitle: String {
        switch releaseUpdates.status {
        case .checking: String(localized: "Checking for Updates…")
        default: String(localized: "Check for Updates")
        }
    }

    private var updateCheckSymbol: String {
        releaseUpdates.status == .checking ? "arrow.triangle.2.circlepath" : "arrow.down.circle"
    }

    @ViewBuilder
    private var updateStatusDetail: some View {
        switch releaseUpdates.status {
        case .idle, .checking:
            EmptyView()
        case .updateAvailable(let release):
            Link(destination: release.releaseURL) {
                Label(
                    String(
                        format: NSLocalizedString("View release %@", comment: ""),
                        release.version
                    ),
                    systemImage: "arrow.up.right.square"
                )
            }
            Text(
                String(
                    format: NSLocalizedString("A newer public release is available: %@.", comment: ""),
                    release.name
                )
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        case .current(let release):
            Label(
                String(
                    format: NSLocalizedString("You have the latest public release (%@).", comment: ""),
                    release.version
                ),
                systemImage: "checkmark.circle"
            )
                .font(.subheadline)
                .foregroundStyle(.green)
        case .newerLocalBuild(let release):
            Link(destination: release.releaseURL) {
                Label(
                    String(
                        format: NSLocalizedString("View public release %@", comment: ""),
                        release.version
                    ),
                    systemImage: "arrow.up.right.square"
                )
            }
            Text(
                String(
                    format: NSLocalizedString("You are using a newer local test build (%@ Build %@).", comment: ""),
                    versionText,
                    buildNumberText
                )
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        case .noPublishedRelease:
            Label("No public GitHub release has been published yet.", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .unavailable:
            Label("Couldn’t check GitHub right now. Try again later.", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var isShowingResetError: Binding<Bool> {
        Binding(
            get: { resetError != nil },
            set: { if !$0 { resetError = nil } }
        )
    }

    @MainActor
    private func resetApp() async {
        do {
            try await appModel.resetApp()
            dismiss()
        } catch {
            resetError = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
        .environment(ReleaseUpdateModel())
}
