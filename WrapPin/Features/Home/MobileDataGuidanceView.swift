import SwiftUI

struct MobileDataGuidanceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let guidance: MobileDataGuidance
    let tunnelHandoffApp: TunnelHandoffApp
    let usesBuiltInTunnel: Bool
    let isUsingMobileData: Bool
    let onOpenTunnelApp: () -> Void
    let onRetry: () -> Void
    let onUseMobileData: () -> Void
    let onMobileDataOff: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(.vertical, showsIndicators: false) {
                content
            }
            .frame(maxHeight: 540)
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 28)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
    }

    private var content: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColours,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 68 : 82,
                        height: dynamicTypeSize.isAccessibilitySize ? 68 : 82
                    )

                Image(systemName: iconSymbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if guidance == .connectionHelp {
                Label(
                    "WrapPin has not found the paired iPhone's device connection yet.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                if !usesBuiltInTunnel {
                    Button(openTunnelAppTitle, action: onOpenTunnelApp)
                        .buttonStyle(.bordered)
                }

                if TunnelHandoffPolicy.offersMobileDataWorkaround(for: tunnelHandoffApp) {
                    Button("I'm Using Mobile Data", action: onUseMobileData)
                        .buttonStyle(.bordered)
                }

                Button("Cancel", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else if guidance == .turnOff {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("Detecting this iPhone…")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: Capsule())

                Label(
                    "WrapPin should continue automatically. If it doesn't, tap Continue.",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button("Continue", action: onMobileDataOff)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                if !usesBuiltInTunnel {
                    Button(openTunnelAppTitle, action: onOpenTunnelApp)
                        .buttonStyle(.bordered)
                }

                Button("Cancel", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else {
                Label("Location is active", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var title: String {
        switch guidance {
        case .connectionHelp:
            if !usesBuiltInTunnel && tunnelHandoffApp == .shadowrocket && isUsingMobileData {
                String(localized: "Use Wi-Fi with Shadowrocket")
            } else {
                String(localized: "Still Connecting")
            }
        case .turnOff:
            String(localized: "Turn Mobile Data Off")
        case .turnBackOn:
            String(localized: "Turn Mobile Data Back On")
        }
    }

    private var message: String {
        switch guidance {
        case .connectionHelp:
            if usesBuiltInTunnel {
                return String(localized: "Check that WrapPin's built-in tunnel is connected, then try again. If you are using mobile data, follow the mobile data steps below.")
            }
            if tunnelHandoffApp == .shadowrocket && isUsingMobileData {
                return String(localized: "Shadowrocket may not provide the device connection WrapPin needs over mobile data. Connect to Wi-Fi, keep a compatible tunnel on, then return and try again.")
            } else {
                return String(localized: "Make sure the selected app's tunnel is connected, then try again. Choose mobile data only when you're actually using 4G or 5G.")
            }
        case .turnOff:
            if usesBuiltInTunnel {
                return String(localized: "Keep the built-in tunnel connected, switch mobile data off briefly, then return to WrapPin.")
            }
            return String(localized: "Make sure LocalDevVPN is connected, switch mobile data off briefly, then return to WrapPin.")
        case .turnBackOn:
            return String(localized: "The secure location session is ready. You can restore mobile data now; spoofing will continue over 5G.")
        }
    }

    private var openTunnelAppTitle: String {
        String(format: NSLocalizedString("Open %@", comment: ""), tunnelHandoffApp.title)
    }

    private var iconColours: [Color] {
        switch guidance {
        case .connectionHelp: [.purple, .indigo]
        case .turnOff: [.indigo, .blue]
        case .turnBackOn: [.green, .teal]
        }
    }

    private var iconSymbol: String {
        switch guidance {
        case .connectionHelp: "lock.shield.fill"
        case .turnOff: "antenna.radiowaves.left.and.right"
        case .turnBackOn: "checkmark"
        }
    }
}
