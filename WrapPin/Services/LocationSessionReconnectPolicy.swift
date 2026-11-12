import Foundation

/// Applies only to a session started in this process that reached an active
/// location. Persisted, unconfirmed sessions still require the user's action.
struct LocationSessionReconnectPolicy {
    private(set) var attemptCount = 0
    private(set) var hasBeenActive = false
    private var activeSince: Date?

    mutating func becameActive(at date: Date = .now) {
        hasBeenActive = true
        activeSince = date
    }

    mutating func nextDelay(after stage: FailureStage?, at date: Date = .now) -> TimeInterval? {
        guard hasBeenActive else { return nil }
        switch stage {
        case .vpnConnection, .tunnelCreation, .tunnelConnection,
             .serviceDirectory, .serviceHandshake, .locationService,
             .locationInitialWrite, .locationActiveWrite:
            break
        default:
            // Authentication, corrupt pairing and stop/clear errors need user
            // attention. Repeating them must not revive a stopped session.
            return nil
        }
        if let activeSince, date.timeIntervalSince(activeSince) >= 60 {
            attemptCount = 0
        }
        activeSince = nil
        guard attemptCount < 3 else { return nil }
        let delay = TimeInterval(1 << attemptCount)
        attemptCount += 1
        return delay
    }
}
