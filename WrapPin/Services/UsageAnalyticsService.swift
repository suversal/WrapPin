import CryptoKit
import Foundation

enum UsageAnalyticsEvent: String {
    case connectionHelpShown = "WrapPin.Connection.HelpShown"
    case connectionRetrySelected = "WrapPin.Connection.RetrySelected"
    case connectionRetrySucceeded = "WrapPin.Connection.RetrySucceeded"
    case connectionRecoveryNeeded = "WrapPin.Connection.RecoveryNeeded"
    case failureObserved = "WrapPin.Failure.Observed"
    case participationStarted = "WrapPin.Analytics.participationStarted"
    case appActivated = "WrapPin.App.activated"
    case onboardingCompleted = "WrapPin.Onboarding.completed"
    case pairingCompleted = "WrapPin.Pairing.completed"
    case pairingFailed = "WrapPin.Pairing.Failed"
    case fixedLocationStarted = "WrapPin.Location.fixedStarted"
    case walkingStarted = "WrapPin.Location.walkingStarted"
    case drivingStarted = "WrapPin.Location.drivingStarted"
    case activeLocationUpdated = "WrapPin.Location.activeUpdated"
    case locationPreparationFailed = "WrapPin.Location.PreparationFailed"
    case locationRestoreFailed = "WrapPin.Location.RestoreFailed"
    case localDevVPNUnreachable = "WrapPin.LocalDevVPN.Unreachable"
    case locationStartFailed = "WrapPin.Location.StartFailed"
}

/// Sends a deliberately small, fixed set of anonymous usage signals.
///
/// This client does not use a third-party SDK so disabling statistics takes
/// effect immediately and no automatic device metadata can be added. It never
/// accepts locations, search text, pairing data, device names or free-form
/// parameters.
@MainActor
final class UsageAnalyticsService {
    private static let anonymousIdentifierKey = "anonymousUsageIdentifier"
    private static let hasReportedParticipationKey = "hasReportedAnalyticsParticipation"

    private let preferences: UserDefaults
    private let urlSession: URLSession
    private var reportingEnabled = false
    private var consentRevision = 0
    private var participationAttemptID: UUID?
    private var lastActivationDate: Date?

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        self.urlSession = URLSession(configuration: configuration)
    }

    func recordActivation(enabled: Bool) {
        reportingEnabled = enabled
        guard enabled, let configuration = Self.configuration else { return }

        let now = Date.now
        if let lastActivationDate, now.timeIntervalSince(lastActivationDate) < 3 {
            return
        }
        lastActivationDate = now

        reportParticipationIfNeeded(configuration: configuration)
        send(.appActivated, configuration: configuration)
    }

    func record(_ event: UsageAnalyticsEvent, enabled: Bool) {
        guard enabled, let configuration = Self.configuration else { return }
        send(event, configuration: configuration)
    }

    func revokeLocalIdentity() {
        reportingEnabled = false
        consentRevision += 1
        participationAttemptID = nil
        lastActivationDate = nil
        preferences.removeObject(forKey: Self.anonymousIdentifierKey)
        preferences.removeObject(forKey: Self.hasReportedParticipationKey)
    }

    func recordFailure(_ stage: FailureStage, context: FailureContext, disposition: FailureDisposition = .terminal, schedulerReason: SchedulerFailureReason? = nil, enabled: Bool) {
        guard enabled, let configuration = Self.configuration else { return }
        send(disposition.event, configuration: configuration, failure: (stage, context, disposition, schedulerReason))
    }

    private func reportParticipationIfNeeded(
        configuration: AnalyticsConfiguration
    ) {
        guard
            !preferences.bool(forKey: Self.hasReportedParticipationKey),
            participationAttemptID == nil
        else { return }

        let attemptID = UUID()
        let revision = consentRevision
        participationAttemptID = attemptID

        send(.participationStarted, configuration: configuration) { [weak self] succeeded in
            guard let self, self.participationAttemptID == attemptID else { return }
            self.participationAttemptID = nil
            guard
                succeeded,
                self.reportingEnabled,
                self.consentRevision == revision
            else { return }
            self.preferences.set(true, forKey: Self.hasReportedParticipationKey)
        }
    }

    private func send(
        _ event: UsageAnalyticsEvent,
        configuration: AnalyticsConfiguration,
        failure: (FailureStage, FailureContext, FailureDisposition, SchedulerFailureReason?)? = nil,
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        var payload = Self.safePayload
        if let (stage, context, disposition, schedulerReason) = failure {
            if let schedulerReason {
                payload["WrapPin.schedulerReason"] = schedulerReason.rawValue
            }
            payload["WrapPin.failureDisposition"] = disposition.rawValue
            payload["WrapPin.failureStage"] = stage.rawValue
            payload["WrapPin.failureContext"] = context.rawValue
        }
        let body = AnalyticsSignal(
            appID: configuration.appID,
            clientUser: anonymousClientIdentifier,
            type: event.rawValue,
            isTestMode: Self.isDebugBuild,
            payload: payload
        )

        guard let data = try? JSONEncoder().encode([body]) else {
            completion?(false)
            return
        }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "application/json; charset=utf-8",
            forHTTPHeaderField: "Content-Type"
        )

        let session = urlSession
        Task {
            do {
                let (_, response) = try await session.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                completion?(statusCode.map { (200..<300).contains($0) } ?? false)
            } catch {
                completion?(false)
            }
        }
    }

    private var anonymousClientIdentifier: String {
        if let existing = preferences.string(forKey: Self.anonymousIdentifierKey) {
            return Self.hash(existing)
        }

        let identifier = UUID().uuidString
        preferences.set(identifier, forKey: Self.anonymousIdentifierKey)
        return Self.hash(identifier)
    }

    private static var configuration: AnalyticsConfiguration? {
        guard
            let appID = configuredValue(for: "WrapPinTelemetryAppID"),
            let namespace = configuredValue(for: "WrapPinTelemetryNamespace"),
            let encodedNamespace = namespace.addingPercentEncoding(
                withAllowedCharacters: .alphanumerics
            ),
            let endpoint = URL(
                string: "https://nom.telemetrydeck.com/v2/namespace/\(encodedNamespace)/"
            )
        else { return nil }

        return AnalyticsConfiguration(appID: appID, endpoint: endpoint)
    }

    private static func configuredValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private static var safePayload: [String: String] {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "Unknown"

        return [
            "WrapPin.appVersion": version,
            "WrapPin.buildNumber": build
        ]
    }

    private static var isDebugBuild: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private struct AnalyticsConfiguration {
    let appID: String
    let endpoint: URL
}

private struct AnalyticsSignal: Encodable {
    let appID: String
    let clientUser: String
    let type: String
    let isTestMode: Bool
    let payload: [String: String]
}

// Values are fixed categories. Error text and native stage codes are mapped locally;
// only the category is ever transmitted.
enum FailureContext: String {
    case pairing, location, restoration
}

enum FailureStage: String, CaseIterable {
    case pairingRecord
    case discovery
    case vpnConnection
    case pairVerification
    case tunnelCreation
    case tunnelConnection
    case tunnelSecurity
    case serviceDirectory
    case serviceHandshake
    case locationService
    case locationInitialWrite
    case locationActiveWrite
    case locationEngine
    case schedulerRegistration
    case schedulerSubmission
    case pairingAdvertisement
    case pairingConnection
    case pairingAuthentication
    case pairingExpired
    case pairingEngine
    case pairingStorage
    case pairingImport
    case pairingRead
    case locationPreparation
    case locationRestore
    case pairingUnknown
    case locationUnknown

    /// Maps the stage code reported by the native location engine
    /// (`LocationStage` in Native/WrapPinPairingFFI/src/lib.rs). Unknown,
    /// cancelled and unrecognised codes have no stage of their own.
    init?(nativeLocationStage code: Int32) {
        switch code {
        case 1: self = .pairingRecord
        case 2: self = .discovery
        case 3: self = .vpnConnection
        case 4: self = .pairVerification
        case 5: self = .tunnelCreation
        case 6: self = .tunnelConnection
        case 7: self = .tunnelSecurity
        case 8: self = .serviceDirectory
        case 9: self = .serviceHandshake
        case 10: self = .locationService
        case 11: self = .locationInitialWrite
        case 12: self = .locationActiveWrite
        case 13: self = .locationEngine
        case 14: self = .locationRestore
        default: return nil
        }
    }

    static let nativeLocationCancelledCode: Int32 = 15

    /// Classifies the pairing engine's English error text. Pass the original
    /// message, never a localized one. Location sessions report a stage code
    /// instead; see `init(nativeLocationStage:)`.
    static func classify(_ message: String, fallback: FailureStage) -> FailureStage {
        switch message {
        case "WrapPin could not securely store the new pairing.": return .pairingStorage
        case "iOS could not prepare the location session. Close WrapPin, reopen it, and try again.",
             "iOS could not register the secure pairing task. Close WrapPin, reopen it, and try again.": return .schedulerRegistration
        case "iOS could not keep pairing active in the background. Keep WrapPin open and try again.": return .schedulerSubmission
        case "Local Network access is required. Enable it in Settings › Apps › WrapPin, then try again.": return .pairingAdvertisement
        case "WrapPin could not open a local pairing connection.",
             "WrapPin could not determine its pairing port.",
             "The iPhone could not connect to WrapPin.",
             "The iPhone ended the pairing connection. Start pairing again when you are ready.": return .pairingConnection
        case "The code was not accepted. Start pairing again and enter the new code.": return .pairingAuthentication
        case "Pairing took too long. Return to WrapPin and try again.": return .pairingExpired
        case "WrapPin could not start its pairing engine.",
             "The pairing engine returned an empty record.": return .pairingEngine
        default: return fallback
        }
    }
}

// Tracks only local retry state, never an identifier or location.
struct ConnectionRetryTelemetry {
    private var retryPending = false

    mutating func reset() { retryPending = false }

    mutating func selected() -> UsageAnalyticsEvent {
        retryPending = true
        return .connectionRetrySelected
    }

    mutating func becameActive() -> UsageAnalyticsEvent? {
        guard retryPending else { return nil }
        retryPending = false
        return .connectionRetrySucceeded
    }
}

// Terminal means the current operation ended unsuccessfully; a later user retry may succeed.
enum FailureDisposition: String {
    case terminal, recoverable

    var event: UsageAnalyticsEvent {
        switch self {
        case .terminal: .failureObserved
        case .recoverable: .connectionRecoveryNeeded
        }
    }
}

// Never serialize NSError's description, userInfo, domain or numeric code.
enum SchedulerFailureReason: String {
    case unavailable, tooManyPendingRequests, notPermitted, immediateRunIneligible, unknown

    static func classify(_ error: Error) -> Self {
        let error = error as NSError
        guard error.domain == "BGTaskSchedulerErrorDomain" else { return .unknown }
        switch error.code {
        case 1: return .unavailable
        case 2: return .tooManyPendingRequests
        case 3: return .notPermitted
        case 4: return .immediateRunIneligible
        default: return .unknown
        }
    }

    var pairingGuidance: String {
        switch self {
        case .unavailable:
            "iOS background processing is unavailable. Check Background App Refresh for WrapPin in Settings, then try again."
        case .tooManyPendingRequests:
            "iOS has too many pending background tasks. Let other tasks finish, then return to WrapPin and try pairing again."
        case .notPermitted:
            "iOS did not permit the pairing background task. Copy Diagnostics from Connection Health so this installation can be checked."
        case .immediateRunIneligible:
            "iOS could not start pairing immediately under current system conditions. Keep WrapPin open and try again shortly."
        case .unknown:
            "iOS could not schedule pairing. Try again, and copy Diagnostics from Connection Health if it continues."
        }
    }
}
