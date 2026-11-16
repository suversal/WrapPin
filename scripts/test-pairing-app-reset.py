#!/usr/bin/env python3
"""Exercise actual AppModel reset/import/read methods with suspended storage."""
from pathlib import Path
import re
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'WrapPin/App/AppModel.swift').read_text()
def method(marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 0
    for i in range(opening, len(source)):
        depth += (source[i] == '{') - (source[i] == '}')
        if depth == 0:
            return source[start:i+1]
    raise AssertionError(marker)
methods = source[source.index('    private(set) var isResettingPairing'):source.index('    func resetApp()')]
for marker in ['    func restorePairingStatus()', '    private func importPairingRecord(using', '    var isChangingPairingUnavailable:', '    func removePairingRecord()']:
    methods += method(marker) + '\n'
methods = re.sub(r'\bprivate\b', 'fileprivate', methods)
fakes = r'''
import Foundation
struct PairingRecordSummary: Equatable { let identifier: String }
enum PairingStatus: Equatable { case checking, importing, notPaired, paired(PairingRecordSummary), failed(message: String) }
enum ConnectionState: Equatable { case ready, active, notConfigured, failed(message: String) }
@MainActor final class PairingFake {
    var isRunning = false
    func reset() async {}
}
@MainActor final class SessionFake {
    enum Phase { case idle }
    var isBusy = false
    var phase = Phase.idle
    func resetAndWait() async {}
}
@MainActor final class AnalyticsFake {
    enum Event { case pairingFailed }
    enum Stage { case pairingRead, pairingImport }
    enum Context { case pairing }
    func record(_ event: Event, enabled: Bool) {}
    func recordFailure(_ stage: Stage, context: Context, enabled: Bool) {}
}
@MainActor final class StoreFake {
    var value: PairingRecordSummary? = .init(identifier: "old")
    var readStarted = false
    var readGate: CheckedContinuation<Void, Never>?
    var delayReads = false
    var deletes = 0
    func storedRecord() async throws -> PairingRecordSummary? {
        let snapshot = value
        if delayReads {
            readStarted = true
            await withCheckedContinuation { readGate = $0 }
        }
        return snapshot
    }
    func removeRecord() async throws { value = nil; deletes += 1 }
}
@MainActor final class Model {
    let onDevicePairing = PairingFake()
    let deviceSession = SessionFake()
    let pairingService = StoreFake()
    let usageAnalytics = AnalyticsFake()
    var pairingStatus = PairingStatus.notPaired
    var connectionState = ConnectionState.notConfigured
    var pairingImportError: String?
    var sharesAnonymousUsageStatistics = false
    var isStartingLocationSession = false
    var isRestoringInterruptedSession = false
    func cancelPendingLocationPreparation() -> Bool { false }
'''
checks = r'''
}
@main struct Tests {
    @MainActor static func wait(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Storage gate timeout")
    }
    @MainActor static func main() async {
        let model = Model()
        model.pairingService.delayReads = true
        let read = Task { await model.restorePairingStatus() }
        await wait { model.pairingService.readStarted }
        await model.removePairingRecord()
        model.pairingService.readGate?.resume()
        await read.value
        precondition(model.pairingStatus == .notPaired && model.connectionState == .notConfigured,
            "Late Keychain read restored the old UI state")

        var importGate: CheckedContinuation<Void, Never>?
        let importing = Task {
            await model.importPairingRecord {
                await withCheckedContinuation { importGate = $0 }
                let summary = PairingRecordSummary(identifier: "new")
                model.pairingService.value = summary
                return summary
            }
        }
        await wait { importGate != nil }
        var resetFinished = false
        let reset = Task { await model.removePairingRecord(); resetFinished = true }
        await wait { model.isResettingPairing }
        precondition(!resetFinished && model.isChangingPairingUnavailable)
        let deletesBefore = model.pairingService.deletes
        // Concurrent reset is coalesced and cannot permit another import.
        await model.removePairingRecord()
        await model.importPairingRecord { preconditionFailure("Import admitted during reset") }
        precondition(model.pairingService.deletes == deletesBefore)
        importGate?.resume()
        await importing.value
        await reset.value
        precondition(model.pairingService.value == nil && model.pairingStatus == .notPaired)
        precondition(!model.isResettingPairing && resetFinished)
        print("Production AppModel checks passed: late read invalidated, import drained before deletion, concurrent reset/import blocked")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='wrappin-app-reset-') as temp:
    swift = Path(temp) / 'Checks.swift'
    swift.write_text(fakes + methods + checks)
    binary = Path(temp) / 'check'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', str(Path(temp)/'cache'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=30)
