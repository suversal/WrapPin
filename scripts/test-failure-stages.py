#!/usr/bin/env python3
"""Compile the production classifier and check native stage-code coverage without sending events."""
from pathlib import Path
import json, re, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
swift = (root / 'WrapPin/Services/UsageAnalyticsService.swift').read_text()
enums = 'import Foundation\n' + swift[swift.index('enum UsageAnalyticsEvent:'):swift.index('/// Sends')] + swift[swift.index('enum FailureContext:'):]
native = (root / 'Native/WrapPinPairingFFI/src/lib.rs').read_text()
header = (root / 'Native/WrapPinPairingFFI/include/wrappin_pairing.h').read_text()
# The location engine reports a numbered stage; Rust, the C header and Swift must agree.
stage_enum = native[native.index('enum LocationStage {'):]
stages = {name: int(code) for name, code in re.findall(r'(\w+) = (\d+),', stage_enum[:stage_enum.index('}')])}
assert stages == {name: int(code) for name, code in re.findall(r'WPLocationStage(\w+) = (\d+)', header)}
assert stages['Unknown'] == 0 and len(set(stages.values())) == len(stages)
production = native[:native.index('#[cfg(test)]')]
errors = re.findall(r'LocationError::(?:new|recoverable)\(\s*(?:\w+::)?(\w+),\s*"([^"\n]+)"', production)
assert len(errors) >= 30
assert all(stage in stages for stage, _ in errors)
# Session failures other than cancellation and invalid coordinates must carry a real stage.
assert [message for stage, message in errors if stage == 'Unknown'] == []
checks = [
 f'precondition(FailureStage.nativeLocationCancelledCode == {stages["Cancelled"]})',
 'precondition(FailureStage(nativeLocationStage: 0) == nil)',
 f'precondition(FailureStage(nativeLocationStage: {stages["Cancelled"]}) == nil)',
 'precondition(FailureStage(nativeLocationStage: 99) == nil)',
 'precondition(FailureStage(nativeLocationStage: -1) == nil)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 1)) == .unavailable)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 2)) == .tooManyPendingRequests)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 3)) == .notPermitted)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 4)) == .immediateRunIneligible)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 99)) == .unknown)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "private network detail", code: 4, userInfo: [NSLocalizedDescriptionKey: "credential PIN device name"])) == .unknown)',

 'precondition(FailureDisposition.terminal.event == .failureObserved)',
 'precondition(FailureDisposition.recoverable.event == .connectionRecoveryNeeded)',
]
coordinator = (root / 'WrapPin/Services/Tunnel/LocalDeviceSessionCoordinator.swift').read_text()
assert 'onRecoveryNeeded?(stage)' in coordinator
assert 'onFailure?(stage)' in coordinator
assert 'self.onFailure?(.schedulerSubmission)' not in coordinator
assert 'submitTaskRequest' not in coordinator
# Session failures are classified by stage code, never by (possibly localized) wording.
assert 'FailureStage.classify' not in coordinator
assert 'localizedCaseInsensitiveContains' not in coordinator
for name, code in stages.items():
    if name in ('Unknown', 'Cancelled'):
        continue
    checks.append(f'precondition(FailureStage(nativeLocationStage: {code})?.rawValue == {json.dumps(name[0].lower() + name[1:])})')
# Pairing still reports English text; every message the pairing engine can return needs a stage.
pairing = native[native.index('async fn run_pairing('):native.index('async fn run_location_session(')] + native[native.index('fn friendly_pairing_error('):native.index('unsafe fn optional_c_string(')]
pairing_messages = re.findall(r'"([^"\n]+)"\s*\.to_string\(\)', pairing)
assert len(pairing_messages) >= 5
# The engine's catch-all has no specific cause, so it deliberately stays in the fallback stage.
unclassified_pairing = 'The iPhone could not finish pairing. Please try again.'
assert unclassified_pairing in pairing_messages
pairing_messages.remove(unclassified_pairing)
checks.append('precondition(FailureStage.classify(' + json.dumps(unclassified_pairing) + ', fallback: .pairingUnknown) == .pairingUnknown)')
for message in pairing_messages:
    checks.append('precondition(FailureStage.classify(' + json.dumps(message) + ', fallback: .pairingUnknown) != .pairingUnknown)')
checks += [
 'precondition(FailureStage.classify("The code was not accepted. Start pairing again and enter the new code.", fallback: .pairingUnknown) == .pairingAuthentication)',
 'precondition(FailureStage.classify("The iPhone rejected the saved pairing session.", fallback: .locationUnknown) == .locationUnknown)',
 'precondition(FailureStage.classify("WrapPin could not securely store the new pairing.", fallback: .pairingUnknown) == .pairingStorage)',
 'precondition(FailureStage.classify("private device name PIN 123456 coordinates 51.5,-0.1", fallback: .locationUnknown) == .locationUnknown)',
 'precondition(FailureStage.classify("unknown credentials", fallback: .pairingUnknown) == .pairingUnknown)',
 'precondition(FailureStage.allCases.allSatisfy { $0.rawValue.allSatisfy { $0.isLetter } })',
]
with tempfile.TemporaryDirectory() as temp:
    source = Path(temp) / 'main.swift'
    source.write_text(enums + '\n' + '\n'.join(checks) + '\nprint("Failure-stage checks passed")\n')
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(temp) / 'cache'), str(source), '-o', str(Path(temp) / 'check')], check=True)
    subprocess.run([str(Path(temp) / 'check')], check=True)
print(f'Covered {len(stages)} native stage codes across {len(errors)} location errors and {len(pairing_messages)} pairing messages; no network requests made.')
