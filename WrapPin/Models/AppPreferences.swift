import Foundation

enum TunnelHandoffApp: String, CaseIterable, Identifiable {
    case localDevVPN
    case shadowrocket
    case surge
    case loon

    var id: Self { self }

    var title: String {
        switch self {
        case .localDevVPN: "LocalDevVPN"
        case .shadowrocket: "Shadowrocket"
        case .surge: "Surge"
        case .loon: "Loon"
        }
    }

    /// Opens the app itself, without asking it to change its tunnel.
    var appURL: URL {
        switch self {
        case .localDevVPN: URL(string: "localdevvpn://")!
        case .shadowrocket: URL(string: "shadowrocket://")!
        case .surge: URL(string: "surge://")!
        case .loon: URL(string: "loon://")!
        }
    }

    // LocalDevVPN returns through a callback; Shadowrocket, Surge and Loon each have a start action.
    var launchURL: URL {
        switch self {
        case .localDevVPN: URL(string: "localdevvpn://enable?scheme=\(BuildEdition.callbackScheme)")!
        case .shadowrocket: URL(string: "shadowrocket://connect")!
        case .surge: URL(string: "surge:///start")!
        case .loon: URL(string: "loon://on")!
        }
    }
}

enum TunnelHandoffPolicy {
    static func offersMobileDataWorkaround(for app: TunnelHandoffApp) -> Bool {
        app == .localDevVPN
    }

    static func recommendsWiFiWhenUnavailable(for app: TunnelHandoffApp) -> Bool {
        app != .localDevVPN
    }

    static func requiresLocalDevVPNCellularHandoff(
        app: TunnelHandoffApp,
        isWiFiPathKnown: Bool,
        isWiFiSatisfied: Bool
    ) -> Bool {
        app == .localDevVPN && isWiFiPathKnown && !isWiFiSatisfied
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: String(localized: "Auto")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

enum MapDisplayStyle: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .satellite: String(localized: "Satellite")
        case .hybrid: String(localized: "Hybrid")
        }
    }
}
