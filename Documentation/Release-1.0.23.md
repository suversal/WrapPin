# WrapPin 1.0.23 (Build 75)

[简体中文](Release-1.0.23.zh-CN.md)

This release improves new on-device pairing and reset recovery.

- New pairing attempts use a random host identifier consistent with their new signing keys. Existing saved pairings remain usable across ordinary launches and location reconnects.
- The advertised pairing port explicitly accepts IPv4 and IPv6.
- Reset waits for old pairing workers, generated/imported-record writes and location shutdown before deleting and checking the app's own Keychain record. Late reads and callbacks cannot restore an old UI state. Location shutdown still uses the normal restoration/acknowledgement path.
- Delayed Bonjour callbacks no longer hide a generated PIN. Cancellation requested before native startup is preserved, and a pairing attempt has a 120-second native deadline in addition to iOS background expiration.
- Copy Diagnostics includes up to 32 in-memory pairing progress entries with elapsed time and address family. No PINs, addresses, device identifiers, keys or pairing files are included. The log is cleared on the next pairing attempt and is not uploaded.
- Return to WrapPin to read the PIN after initiating pairing in iOS Settings; the app does not send PIN notifications.

## Packages

[Download v1.0.23](https://github.com/suversal/WrapPin/releases/tag/v1.0.23). Both packages are unsigned for iOS/iPadOS 18.0+.

- Standard: SideStore/self-signing with an external device tunnel such as LocalDevVPN.
- Tunnel: includes the device tunnel and requires matching app/extension Packet Tunnel signing permissions. Free accounts should use Standard.

Upgrade the same edition using the existing signing identity. There is no need to remove a working pairing. iOS 18–26 continues to import a computer-generated RPPairing record; on-device PIN setup requires iOS 27.

## Verification and limits

Native tests cover identity rotation/roundtrip, actual IPv4/IPv6 loopback acceptance and cancellation before worker startup. Production Swift fault injection covers reset while waiting for the native worker or storage, retry isolation, delayed PIN/publication callbacks, diagnostic privacy, import/reset interleaving and late Keychain reads. Existing offline regressions and both editions' Debug/Release builds and package checks are recorded in the [receipt](../Releases/PairingReset-build75/receipt.json).

The affected iPhone's missing-PIN failure has not been reproduced in this environment. Physical-device pairing, beta-system behavior and signed installation still require acceptance. These changes address confirmed implementation gaps; they do not prove the original incident had a single identified cause. No system-wide reset or unrelated app-data deletion is performed.
