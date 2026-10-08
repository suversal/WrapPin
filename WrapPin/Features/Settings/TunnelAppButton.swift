import SwiftUI
import UIKit

/// Opens the selected tunnel app when it is installed; otherwise offers its
/// App Store page. It never asks the app to change its tunnel.
struct TunnelAppButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openURL) private var openURL

    /// Stretches the label so a bordered button spans its container.
    var fillsWidth = false

    var body: some View {
        let tunnelApp = appModel.tunnelHandoffApp
        let isInstalled = UIApplication.shared.canOpenURL(tunnelApp.appURL)
        Button {
            openURL(isInstalled ? tunnelApp.appURL : appModel.selectedTunnelAppInstallURL)
        } label: {
            Label(
                String(
                    format: NSLocalizedString(isInstalled ? "Open %@" : "Get %@", comment: ""),
                    tunnelApp.title
                ),
                systemImage: isInstalled ? "arrow.up.right.square" : "arrow.down.circle"
            )
            .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
    }
}
