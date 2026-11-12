import Foundation

@main struct LocationReconnectPolicyCheck {
    static func main() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        var policy = LocationSessionReconnectPolicy()
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start) == nil)
        policy.becameActive(at: start)
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start + 5) == 1)
        precondition(policy.nextDelay(after: .vpnConnection, at: start + 6) == 2)
        precondition(policy.nextDelay(after: .tunnelConnection, at: start + 8) == 4)
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start + 12) == nil)
        precondition(policy.attemptCount == 3)
        // Elapsed wall time while disconnected does not replenish the retry budget.
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start + 600) == nil)
        policy.becameActive(at: start + 601)
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start + 660) == nil)
        policy.becameActive(at: start + 661)
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start + 721) == 1)

        for stage in [FailureStage.pairVerification, .pairingRecord, .tunnelSecurity,
                      .locationRestore, .locationPreparation, .locationEngine] {
            var protected = LocationSessionReconnectPolicy()
            protected.becameActive(at: start)
            precondition(protected.nextDelay(after: stage, at: start + 5) == nil)
            precondition(protected.attemptCount == 0)
        }
        var unknown = LocationSessionReconnectPolicy()
        unknown.becameActive(at: start)
        precondition(unknown.nextDelay(after: nil) == nil)
        // A new user session has no authority to reconnect until it becomes active.
        policy = LocationSessionReconnectPolicy()
        precondition(!policy.hasBeenActive && policy.attemptCount == 0)
        precondition(policy.nextDelay(after: .locationActiveWrite, at: start) == nil)
        print("Reconnect policy: active-session eligibility, bounded backoff, stable reset, authentication and restore exclusions passed")
    }
}
