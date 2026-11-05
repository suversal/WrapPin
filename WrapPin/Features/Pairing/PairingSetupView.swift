import SwiftUI
import UIKit
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
                    if !DevicePairingSupport.supportsOnDevicePairing {
                        computerPairingCard
                    }
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
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await appModel.importPairingRecord(from: url) }
            case .failure(let error):
                let nsError = error as NSError
                guard !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError) else { return }
                appModel.pairingImportError = String(localized: "The pairing file could not be opened. Save it in Files and try importing it again.")
            }
        }
        .alert("Could Not Import Pairing File", isPresented: Binding(
            get: { appModel.pairingImportError != nil },
            set: { if !$0 { appModel.pairingImportError = nil } }
        )) {
            Button("OK", role: .cancel) { appModel.pairingImportError = nil }
        } message: {
            Text(appModel.pairingImportError ?? "")
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
                .disabled(isBusy)

                Button("Remove Pairing", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .frame(maxWidth: .infinity)
                .disabled(isBusy)
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
                } else if DevicePairingSupport.supportsOnDevicePairing {
                    Label("On-device pairing needs your physical iPhone.", systemImage: "iphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if DevicePairingSupport.supportsOnDevicePairing {
                    importButton.buttonStyle(.bordered)
                } else {
                    importButton.buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }

                Button {
                    guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        appModel.pairingImportError = String(localized: "Copy the XML contents of your RPPairing file, then try pasting again.")
                        return
                    }
                    Task { await appModel.importPairingRecord(data: Data(text.utf8)) }
                } label: {
                    Label("Paste RPPairing from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .disabled(isBusy)
            }
        }
    }

    private var importButton: some View {
        Button {
            isImporting = true
        } label: {
            Label("Import RPPairing File", systemImage: "doc.badge.plus")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(isBusy)
    }

    private var computerPairingCard: some View {
        setupCard {
            Text("Create a pairing file on your computer")
                .font(.headline)
            requirementRow(number: "1", text: String(localized: "Download idevice_pair on your Mac, Windows or Linux computer."))
            Link("Download idevice_pair", destination: URL(string: "https://github.com/jkcoxson/idevice_pair/releases/latest")!)
                .frame(minHeight: 44, alignment: .leading)
            requirementRow(number: "2", text: String(localized: "Connect this iPhone by USB, unlock it and tap Trust when asked."))
            requirementRow(number: "3", text: String(localized: "Select this iPhone in idevice_pair, choose Remote pairing (RPPairing), then create and save the file."))
            requirementRow(number: "4", text: String(localized: "Transfer the file to this iPhone, save it in Files, then tap Import RPPairing File above."))
            Text("Choose Remote pairing, not Lockdown. A SideStore .mobiledevicepairing file is not a substitute for an RPPairing file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                text: DevicePairingSupport.supportsOnDevicePairing
                    ? String(localized: "Pair this iPhone here, or import its existing RPPairing file.")
                    : String(localized: "Import this iPhone's RPPairing file created with idevice_pair on your computer.")
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

            if DevicePairingSupport.supportsOnDevicePairing {
                Text("New on-device pairing is available on iOS 27. The simulator can test the screen, but Apple only exposes the real handshake on a physical iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
        var types: [UTType] = [.propertyList, .xml]
        if let remotePairing = UTType(filenameExtension: "rppairing") {
            types.append(remotePairing)
        }
        if let mobileDevicePairing = UTType(filenameExtension: "mobiledevicepairing") {
            types.append(mobileDevicePairing)
        }
        return types
    }

    private var isBusy: Bool {
        appModel.isChangingPairingUnavailable
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
            if !DevicePairingSupport.supportsOnDevicePairing {
                return String(localized: "On iOS 26, create an RPPairing file with idevice_pair on your computer, then import it here.")
            }
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
