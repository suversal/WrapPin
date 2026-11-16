#!/usr/bin/env python3
"""Run the production pairing coordinator with a controllable native boundary.

Only UIKit and C FFI are faked; cancellation, callbacks, reset and storage
scheduling execute the production code. No real pairing data or devices.
"""
from pathlib import Path
import subprocess
import re
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'WrapPin/Services/Pairing/OnDevicePairingCoordinator.swift').read_text()
source = source.replace('import UIKit\n', '').replace('import WrapPinPairingFFI\n', '')
# Test visibility only; keep the production implementations intact.
source = re.sub(r'\bprivate\b', 'fileprivate', source)
fakes = r'''
import Foundation
struct PairingRecordSummary: Sendable { let identifier: String }
enum FailureStage { case pairingUnknown, schedulerSubmission, pairingExpired
    static func classify(_ message: String, fallback: Self) -> Self { fallback }
}
enum SchedulerFailureReason { case unknown }
enum DevicePairingSupport { static let supportsOnDevicePairing = true }
struct UIBackgroundTaskIdentifier: Equatable {
    let rawValue: Int
    static let invalid = Self(rawValue: -1)
}
@MainActor final class UIApplication {
    static let shared = UIApplication()
    var tasks = 0
    func beginBackgroundTask(withName: String, expirationHandler: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
        tasks += 1; return .init(rawValue: tasks)
    }
    func endBackgroundTask(_ id: UIBackgroundTaskIdentifier) { tasks -= 1 }
}
typealias WPRemotePairingReadyCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt16, UnsafePointer<UnsafePointer<CChar>?>?, UnsafePointer<UnsafePointer<CChar>?>?, Int) -> Void
typealias WPRemotePairingPINCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void
typealias WPRemotePairingProgressCallback = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Void
struct WPRemotePairingResult {
    var error_message: UnsafeMutablePointer<CChar>? = nil
    var device_name: UnsafeMutablePointer<CChar>? = nil
    var device_model: UnsafeMutablePointer<CChar>? = nil
    var device_udid: UnsafeMutablePointer<CChar>? = nil
    var pairing_record: UnsafeMutablePointer<UInt8>? = nil
    var pairing_record_length = 0
    var host_alt_irk: UnsafeMutablePointer<UInt8>? = nil
    var host_alt_irk_length = 0
}
enum FakeNative {
    static let condition = NSCondition()
    static var sequence = 0
    static var runs = 0
    static var releases: Set<Int> = []
    static var cancellations: Set<Int> = []
    static func release(_ session: OpaquePointer) {
        condition.lock(); releases.insert(Int(bitPattern: session)); condition.broadcast(); condition.unlock()
    }
    static var runCount: Int { condition.lock(); defer { condition.unlock() }; return runs }
}
func wp_remote_pairing_session_create() -> OpaquePointer? {
    FakeNative.condition.lock(); defer { FakeNative.condition.unlock() }
    FakeNative.sequence += 1
    return OpaquePointer(bitPattern: FakeNative.sequence)
}
func wp_remote_pairing_session_cancel(_ session: OpaquePointer) {
    FakeNative.condition.lock(); FakeNative.cancellations.insert(Int(bitPattern: session)); FakeNative.condition.unlock()
}
func wp_remote_pairing_session_run(_ session: OpaquePointer, _ name: UnsafePointer<CChar>, _ model: UnsafePointer<CChar>, _ ready: WPRemotePairingReadyCallback, _ pin: WPRemotePairingPINCallback, _ progress: WPRemotePairingProgressCallback, _ context: UnsafeMutableRawPointer, _ result: UnsafeMutablePointer<WPRemotePairingResult>) -> Int32 {
    let key = Int(bitPattern: session)
    FakeNative.condition.lock()
    FakeNative.runs += 1
    while !FakeNative.releases.contains(key) { FakeNative.condition.wait() }
    let cancelled = FakeNative.cancellations.contains(key)
    FakeNative.condition.unlock()
    if cancelled { return 1 }
    let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    pointer.initialize(to: 1)
    result.pointee.pairing_record = pointer
    result.pointee.pairing_record_length = 1
    return 0
}
func wp_remote_pairing_result_destroy(_ result: UnsafeMutablePointer<WPRemotePairingResult>) {
    result.pointee.pairing_record?.deallocate()
}
func wp_remote_pairing_session_destroy(_ session: OpaquePointer) {}
'''
checks = r'''
@MainActor final class StorageGate {
    var continuation: CheckedContinuation<Void, Never>?
    var value: Data?
    func store(_ data: Data) async -> PairingRecordSummary {
        await withCheckedContinuation { continuation = $0 }
        value = data
        return .init(identifier: "synthetic")
    }
}
@main struct Tests {
    @MainActor static func wait(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<500 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Timed out waiting for fake boundary")
    }
    @MainActor static func main() async {
        let coordinator = OnDevicePairingCoordinator()
        coordinator.start { _, _ in preconditionFailure("Cancelled run stored a record") }
        await wait { FakeNative.runCount == 1 }
        let firstRun = coordinator.activeRunIdentifier!
        let firstSession = coordinator.activeSession!
        coordinator.presentPIN("123456", runIdentifier: firstRun)
        coordinator.advertisementDidPublish()
        precondition(coordinator.phase == .showingPIN("123456"), "Late Bonjour callback hid PIN")
        coordinator.presentPIN("999999", runIdentifier: UUID())
        precondition(coordinator.phase == .showingPIN("123456"), "Stale callback accepted")
        coordinator.nativeProgress(2, runIdentifier: firstRun)
        coordinator.nativeProgress(99, runIdentifier: firstRun)
        precondition(coordinator.diagnosticsText.contains("tcp-connected-ipv4"))
        precondition(!coordinator.diagnosticsText.contains("123456"))
        coordinator.fail("Pairing took too long. Return to WrapPin and try again.")
        let failedPhase = coordinator.phase
        coordinator.presentPIN("333333", runIdentifier: firstRun)
        coordinator.advertisementDidPublish()
        precondition(coordinator.phase == failedPhase, "Late callback revived an expired attempt")
        var resetFinished = false
        let reset = Task { await coordinator.reset(); resetFinished = true }
        await wait { coordinator.phase == .cancelling }
        precondition(!resetFinished && coordinator.isRunning)
        coordinator.start { _, _ in preconditionFailure("Reset allowed a new run") }
        precondition(FakeNative.runCount == 1)
        FakeNative.release(firstSession)
        await reset.value
        precondition(resetFinished && coordinator.phase == .idle && !coordinator.isRunning)
        precondition(UIApplication.shared.tasks == 0)

        let gate = StorageGate()
        coordinator.start { data, _ in await gate.store(data) }
        await wait { FakeNative.runCount == 2 }
        let secondRun = coordinator.activeRunIdentifier!
        let secondSession = coordinator.activeSession!
        // Delayed first-run events cannot affect a new attempt.
        coordinator.presentPIN("111111", runIdentifier: firstRun)
        precondition(coordinator.phase == .preparing)
        coordinator.presentPIN("222222", runIdentifier: secondRun)
        FakeNative.release(secondSession)
        await wait { gate.continuation != nil }
        precondition(coordinator.phase == .storing)
        var storageResetFinished = false
        let storageReset = Task {
            await coordinator.reset()
            gate.value = nil // caller deletes its record only AFTER reset has drained writes
            storageResetFinished = true
        }
        await wait { coordinator.isResetting }
        precondition(!storageResetFinished)
        gate.continuation?.resume()
        await storageReset.value
        precondition(gate.value == nil && coordinator.phase == .idle && !coordinator.isRunning)
        precondition(UIApplication.shared.tasks == 0)
        precondition(!coordinator.diagnosticsText.contains("222222"))
        print("Production pairing reset checks passed: worker drain, storage drain, retry isolation, PIN ordering and diagnostic privacy")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='wrappin-pairing-reset-') as temp:
    swift = Path(temp) / 'Checks.swift'
    swift.write_text(fakes + source + checks)
    binary = Path(temp) / 'check'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', str(Path(temp) / 'cache'), str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=30)
