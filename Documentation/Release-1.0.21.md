# WrapPin 1.0.21 (Build 71)

[简体中文](Release-1.0.21.zh-CN.md)

## Changes

This release adds computer-based pairing for iOS 18–26 and native iPad support, with map controls that leave more room for the map in either orientation.

- **iOS 18 compatibility:** minimum iOS/iPadOS 18.0, with compatible MapKit, address lookup and foreground Shortcuts APIs. Standard and Tunnel each use one package across supported systems.
- **Pairing import:** iOS 18–26 imports a computer-generated Remote pairing record, including explicit XML paste. Validation checks record type, device identity and keys; a rejected replacement preserves the previous valid record. iOS 27 keeps on-device six-digit PIN pairing in Developer settings.
- **iPad landscape:** both orientations are supported. Wide windows separate leading controls from the map. Hide the sidebar with its top button or a left swipe on the header; Show Controls restores it.
- **Portrait and narrow windows:** cards dock above the bottom safe area, with a 420 pt content cap. iPad defaults to compact presentation. Long details and large text scroll within the available space.
- **Disclosure:** fixed-location and route cards share expanded/collapsed state. Compact cards retain primary actions, including Stop & Restore and route Pause/Resume. Header-only dragging avoids competing with scrolling, coordinate selection and speed controls.
- **Map messages:** messages clear the current dock and sidebar.

## Pairing and installation

- Standard: `WrapPin-Standard-1.0.21-build71-unsigned.ipa`, for SideStore and other self-signing. Requires an external device tunnel such as LocalDevVPN.
- Tunnel: `WrapPin-Tunnel-1.0.21-build71-unsigned.ipa`, with a built-in device tunnel. Signing needs matching app and Packet Tunnel extension profiles and entitlements. Free Apple Accounts and SideStore should use Standard.
- Both are unsigned IPAs. Upgrade the same edition using the existing signing identity; pairing normally need not be reset. Editions store pairing records separately.
- iOS 18–26: in idevice_pair choose **Remote pairing → Create**, then **Validate**. Save and import that same record after **Works** appears. Do not choose Lockdown. See [computer pairing](iOS26Pairing.md).
- iOS 27: continue using Pair This Device and the six-digit code in Developer settings.

SHA-256:

- Standard: `d576b512ee3d38e7aeb8468de9b2577a89b776fef765404ec2d4f88f0e62feea`
- Tunnel: `11fdce6da3718805a341be47a1140156f172da36a29db492e19af54503b7954f`

Both packages were built from `e227b46624120696c82653a5dabd89ca9b864485` with Xcode 27.0 (`27A266a`). Subsequent documentation and release commits do not change the packages. [Release](https://github.com/suversal/WrapPin/releases/tag/v1.0.21), [receipt](../Releases/PanelLayout-build71/receipt.json), [Chinese installation checks](../Releases/PanelLayout-build71/测试说明.md).

## Verification and limits

- Both device Debug builds, Release archives, all 11 offline checks and IPA version, minimum OS, arm64, device-family, orientation, extension, license and ZIP checks passed. All packaged app files match the archives byte for byte. The native engine is unchanged.
- UI checks passed on iPad mini and a 375 pt iPhone: bottom docking, both iPad landscape orientations, sidebar hide/restore, fixed/route disclosure, selection preservation across rotation, Pause/Resume and Stop confirmation access, maximum accessibility text, dark mode and reduced-motion rendering. These use synthetic session states and do not validate real pairing, location or restoration.
- Initial Standard success was reported on iOS 26.5, and location/landscape success on iPad iOS 26. Full Build 71 device regression, iOS 18 runtime, other iOS 26 versions, Tunnel and iOS 27 PIN pairing still need acceptance.
- Some native verification errors still share the saved-pairing-expired message. It alone does not prove expiry. Use Settings → Connection Check → Copy Diagnostics to inspect the stage and underlying issue.
- Developer Mode, a working device tunnel and a prepared developer image remain prerequisites. This release adds no image download/mounting feature.
- Existing overseas-search configuration and shared quota are retained. TelemetryDeck is unconfigured; these packages send no usage statistics.

Earlier local candidate records remain available: [Build 69](../Releases/iOS26-build69/receipt.json), [Build 70](../Releases/Compatibility-build70/receipt.json).
