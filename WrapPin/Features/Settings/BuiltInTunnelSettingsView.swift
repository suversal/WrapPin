import NetworkExtension
import SwiftUI

struct BuiltInTunnelSettingsView: View {
    @Environment(AppModel.self) private var appModel
    @StateObject private var tunnel = BuiltInTunnelManager.shared
    @State private var isEditingAddress = false
    @State private var addressDraft = ""
    @State private var addressError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Use Built-in Tunnel for Location Sessions", isOn: Binding(
                    get: { appModel.usesBuiltInTunnel },
                    set: { appModel.setUsesBuiltInTunnel($0) }
                ))
                .disabled(isLocationSessionInProgress)

                LabeledContent("Status", value: statusText)

                Button {
                    if tunnel.status == .connected {
                        tunnel.stop()
                    } else {
                        Task { await tunnel.start() }
                    }
                } label: {
                    Label(tunnel.status == .connected ? "Stop Tunnel" : "Start Tunnel",
                          systemImage: tunnel.status == .connected ? "stop.circle" : "play.circle")
                }
                .disabled(isLocationSessionInProgress || tunnel.isStarting || tunnel.status == .disconnecting)
            } header: {
                Text("Tunnel")
            } footer: {
                Text("WrapPin starts the tunnel when a location session needs it and stops it after a successful restore. A tunnel started here stays on until you stop it. iOS may ask you to allow a VPN configuration the first time.")
            }

            if let error = tunnel.lastError {
                Section("Needs Attention") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = tunnel.lastErrorDetail {
                        Text(detail)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                LabeledContent("Local Address", value: tunnel.localAddress)
                LabeledContent("Peer Address", value: BuiltInTunnelManager.peerAddress)
                Button("Edit Local Address") {
                    addressDraft = tunnel.localAddress
                    addressError = nil
                    isEditingAddress = true
                }
            } header: {
                Text("Addresses")
            } footer: {
                Text("The default address matches this build's existing tunnel. Change only the local IPv4 address if another tool needs a different one. The peer stays at 10.7.0.1. Changes take effect the next time the tunnel starts.")
            }

            Section("How It Works") {
                Text("The tunnel routes only the paired iPhone's 10.7.0.1 connection. Other traffic keeps using your normal network. iOS allows one active VPN at a time, so starting this tunnel may disconnect another VPN.")
                    .foregroundStyle(.secondary)
                Text("The app and its tunnel extension both need signing profiles that allow Packet Tunnel. If iOS rejects the VPN configuration, check the signed installation and the VPN entry in iPhone Settings.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Built-in Tunnel")
        .navigationBarTitleDisplayMode(.inline)
        .task { await tunnel.refresh() }
        .sheet(isPresented: $isEditingAddress) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Local IPv4/CIDR", text: $addressDraft)
                            .keyboardType(.numbersAndPunctuation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityHint("For example, 10.7.0.2/30")
                        if let addressError {
                            Text(addressError).foregroundStyle(.red)
                        }
                    } footer: {
                        Text("Use an IPv4 address with a prefix, such as 10.7.0.2/30. Do not use the peer address 10.7.0.1.")
                    }
                    Section {
                        Button("Restore Default Address") {
                            addressDraft = BuiltInTunnelManager.defaultLocalAddress
                            addressError = nil
                        }
                    }
                }
                .navigationTitle("Local Address")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isEditingAddress = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard tunnel.setLocalAddress(addressDraft) else {
                                addressError = String(localized: "Enter a valid local IPv4 address and prefix. It must differ from 10.7.0.1.")
                                return
                            }
                            isEditingAddress = false
                        }
                    }
                }
            }
        }
    }

    private var isLocationSessionInProgress: Bool {
        if appModel.deviceSession.isBusy { return true }
        if case .active = appModel.deviceSession.phase { return true }
        return false
    }

    private var statusText: String {
        if tunnel.isStarting { return String(localized: "Connecting") }
        switch tunnel.status {
        case .connected: return String(localized: "Connected")
        case .connecting, .reasserting: return String(localized: "Connecting")
        case .disconnecting: return String(localized: "Disconnecting")
        case .disconnected, .invalid:
            if tunnel.hasConfiguration && !tunnel.isConfigurationEnabled {
                return String(localized: "VPN Configuration Disabled")
            }
            return String(localized: "Disconnected")
        @unknown default: return String(localized: "Unknown")
        }
    }
}
