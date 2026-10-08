import SwiftUI
import UniformTypeIdentifiers

struct PairingSetupView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isImporting = false
    @State private var isConfirmingRemoval = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    requirementsCard
                    privacyCard
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Device Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedPairingTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await appModel.importPairingRecord(from: url) }
        }
        .confirmationDialog(
            "Remove this pairing record?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Pairing", role: .destructive) {
                Task { await appModel.removePairingRecord() }
            }
        } message: {
            Text("WrapPin will need a new RPPairing file before it can connect again.")
        }
    }

    private var statusCard: some View {
        setupCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: statusSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(statusTitle). \(statusMessage)")

            if case .paired(let summary) = appModel.pairingStatus {
                Divider()

                pairingDetail(title: String(localized: "Fingerprint"), value: summary.fingerprint, monospaced: true)

                pairingDetail(
                    title: String(localized: "Added"),
                    value: summary.importedAt.formatted(date: .abbreviated, time: .shortened)
                )

                Button("Replace Pairing File") {
                    isImporting = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Remove Pairing", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .frame(maxWidth: .infinity)
            } else {
                pairingProgress

                if appModel.onDevicePairing.isAvailableOnThisDevice {
                    if appModel.onDevicePairing.isRunning {
                        Button("Cancel Pairing", role: .cancel) {
                            appModel.cancelOnDevicePairing()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            appModel.startOnDevicePairing()
                        } label: {
                            Label("Pair This iPhone", systemImage: "iphone.and.arrow.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isBusy)
                    }
                } else {
                    Label("On-device pairing needs your physical iPhone.", systemImage: "iphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Import Existing File", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
    }

    @ViewBuilder
    private var pairingProgress: some View {
        switch appModel.onDevicePairing.phase {
        case .idle, .success, .failed:
            EmptyView()

        case .preparing:
            Divider()
            Label {
                Text("Preparing a secure pairing session…")
            } icon: {
                ProgressView()
            }
            .font(.subheadline)

        case .waitingForSettings:
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Finish in Settings")
                    .font(.subheadline.weight(.semibold))
                instructionRow(String(localized: "Open Settings › Privacy & Security › Developer Mode."))
                instructionRow(String(localized: "Tap Pair with WrapPin."))
                instructionRow(String(localized: "Use the code shown here when iOS asks for it."))
            }

        case .showingPIN(let pin):
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter this code in Settings")
                    .font(.subheadline.weight(.semibold))
                Text(pin.map(String.init).joined(separator: " "))
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel("Pairing code \(pin)")
                Text("The code is generated on this iPhone and expires with this pairing attempt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .storing:
            Divider()
            Label {
                Text("Securing the pairing record in Keychain…")
            } icon: {
                ProgressView()
            }
            .font(.subheadline)

        case .cancelling:
            Divider()
            Label {
                Text("Stopping pairing…")
            } icon: {
                ProgressView()
            }
            .font(.subheadline)
        }
    }

    private var requirementsCard: some View {
        setupCard {
            Text("Before connecting")
                .font(.headline)

            requirementRow(
                number: "1",
                text: String(localized: "Pair this iPhone here, or import its existing RPPairing file.")
            )
            requirementRow(
                number: "2",
                text: appModel.usesBuiltInTunnel
                    ? String(localized: "Allow WrapPin to add its built-in VPN when prompted.")
                    : String(
                        format: NSLocalizedString("Install %@ and switch it on.", comment: ""),
                        appModel.tunnelHandoffApp.title
                    )
            )
            requirementRow(number: "3", text: String(localized: "Keep Developer Mode enabled on the iPhone."))

            if !appModel.usesBuiltInTunnel {
                TunnelAppButton(fillsWidth: true)
                    .buttonStyle(.bordered)
            }

            Text("New on-device pairing is available on iOS 27. The simulator can test the screen, but Apple only exposes the real handshake on a physical iPhone.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacyCard: some View {
        setupCard {
            Label("Stored securely", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(.green)

            Text("The pairing record is generated or checked on this iPhone, then stored only in its Keychain. WrapPin does not upload it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func requirementRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue, in: Circle())

            Text(text)
                .font(.subheadline)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(number). \(text)")
    }

    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.blue)
                .padding(.top, 3)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func pairingDetail(
        title: String,
        value: String,
        monospaced: Bool = false
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(monospaced ? .caption.monospaced() : .caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LabeledContent(title, value: value)
                    .font(monospaced ? .caption.monospaced() : .caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    private var allowedPairingTypes: [UTType] {
        var types: [UTType] = [.propertyList]
        if let mobileDevicePairing = UTType(filenameExtension: "mobiledevicepairing") {
            types.append(mobileDevicePairing)
        }
        return types
    }

    private var isBusy: Bool {
        appModel.pairingStatus == .checking
            || appModel.pairingStatus == .importing
            || appModel.onDevicePairing.isRunning
    }

    private var statusSymbol: String {
        switch appModel.onDevicePairing.phase {
        case .preparing, .waitingForSettings, .showingPIN, .storing, .cancelling:
            return "iphone.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking, .importing: return "arrow.triangle.2.circlepath"
        case .notPaired: return "iphone.badge.exclamationmark"
        case .paired: return "checkmark.shield.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch appModel.onDevicePairing.phase {
        case .preparing, .waitingForSettings, .showingPIN, .storing, .cancelling:
            return .blue
        case .failed:
            return .red
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking, .importing: return .blue
        case .notPaired: return .orange
        case .paired: return .green
        case .failed: return .red
        }
    }

    private var statusTitle: String {
        switch appModel.onDevicePairing.phase {
        case .preparing: return String(localized: "Preparing pairing")
        case .waitingForSettings: return String(localized: "Ready in Settings")
        case .showingPIN: return String(localized: "Pairing code ready")
        case .storing: return String(localized: "Finishing pairing")
        case .cancelling: return String(localized: "Stopping pairing")
        case .failed: return String(localized: "Pairing problem")
        case .idle, .success: break
        }

        switch appModel.pairingStatus {
        case .checking: return String(localized: "Checking this iPhone")
        case .importing: return String(localized: "Checking pairing file")
        case .notPaired: return String(localized: "Pairing required")
        case .paired: return String(localized: "Pairing file ready")
        case .failed: return String(localized: "Pairing problem")
        }
    }

    private var statusMessage: String {
        switch appModel.onDevicePairing.phase {
        case .preparing:
            return String(localized: "Starting a private session on this iPhone.")
        case .waitingForSettings:
            return String(localized: "WrapPin is visible to the iOS pairing screen.")
        case .showingPIN:
            return String(localized: "Enter the six-digit code in Settings to confirm.")
        case .storing:
            return String(localized: "The handshake worked. Saving its keys securely.")
        case .cancelling:
            return String(localized: "Closing the local session and advertisement.")
        case .failed(let message):
            return message
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking:
            return String(localized: "Looking for a securely stored pairing record.")
        case .importing:
            return String(localized: "Validating the record and its keys.")
        case .notPaired:
            return appModel.onDevicePairing.isAvailableOnThisDevice
                ? String(localized: "Create the pairing securely on this iPhone, or import an existing file.")
                : String(localized: "Connect your physical iPhone to create the pairing, or import an existing file.")
        case .paired:
            return appModel.usesBuiltInTunnel
                ? String(localized: "WrapPin can use this record with its built-in device tunnel.")
                : String(
                    format: NSLocalizedString("WrapPin can use this record when the %@ tunnel is connected.", comment: ""),
                    appModel.tunnelHandoffApp.title
                )
        case .failed(let message):
            return message
        }
    }
}

#Preview {
    PairingSetupView()
        .environment(AppModel())
}
