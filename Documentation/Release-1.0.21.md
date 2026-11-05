# 1.0.21 development and candidate notes

## Build 70 — iOS 18+ and iPad compatibility candidate

The minimum OS is now 18.0. iOS 18–26 uses imported computer-generated RPPairing files; iOS 27 keeps on-device pairing. Pre-26 MapKit uses placemarks and CLGeocoder, and Shortcuts uses openAppWhenRun while keeping foreground execution. Both editions remain single packages across supported OS versions. iOS 18 execution is not yet device-verified.

Both editions and the tunnel extension now declare iPad support, including both landscape orientations. Wide windows separate scrollable controls from the map; narrower windows use bounded overlays. Setup pages have readable content widths. Both unsigned packages were archived from source commit `4a42f48b67027709a9057d6eb716bafc7737695a` and verified for minimum iOS 18.0, iPhone/iPad families, orientation, extension and ZIP layout. See the [package receipt](../Releases/Compatibility-build70/receipt.json). See [iPad layout](iPadLayout.md) for validation and pending physical-device acceptance.

## 1.0.21 Build 69 — iOS 26 compatibility candidate

Local candidate dated 5 November 2026 (Asia/Shanghai); not a public release. Based on v1.0.20, with the existing feature set retained and no Build 67/68 experiment changes.

- Minimum iOS version is 26.0 for both apps and the Packet Tunnel extension.
- iOS 26 imports a computer-generated RPPairing file; iOS 27 keeps on-device PIN pairing. Setup guidance follows the system capability.
- File selection and explicit XML paste share validation. Lockdown files, missing device identity and mismatched keys receive actionable errors. A rejected replacement preserves the previous valid record, and active sessions prevent changes.
- Both schemes passed Debug and Release Archive; all 11 offline checks and IPA identity, architecture, minimum OS, extension and ZIP checks passed. The native engine is unchanged and its Rust tests were not repeated.
- Full device acceptance is pending after initial Standard success on iOS 26.5: test Standard and Tunnel across 26.0–26.3 and 26.4 or later, and regress iOS 27 PIN pairing. DDI readiness remains a runtime prerequisite; this candidate adds no image mount/download feature.

See [iOS 26 setup](iOS26Pairing.md) and [package receipt](../Releases/iOS26-build69/receipt.json).

iOS 26.3.1 simulator: launch, Keychain reading after local ad-hoc signing, and the Chinese computer-pairing branch were observed on a 375 pt device. A system Location permission dialog and unavailable interactive Simulator GUI prevented complete light/dark/maximum-text visual acceptance.

## Initial Standard device feedback — 5 November 2026

The user tested Standard Build 69 on iOS 26.5. An initial pairVerification / idevice RemotePairing 103 failure was followed by idevice_pair v1.1.0 reporting Remote pairing Validate → Works. After instructions to save and import that same newly verified record, the user reported success. Restoration, routes, background continuity, reboot, Tunnel and other OS versions were not separately confirmed. The prior failure cause remains unproven. Diagnostic-only error-detail improvements were tested separately and preserved outside this checkout; they are not part of Build 69.

## Known pairing-message limitation

The unchanged native engine still labels several pair-verification failures as an invalid saved pairing. That message alone does not prove the record expired. Use the v1.1.0 Create → Validate (Works) → Save flow, import that same record, and use Connection Health → Copy Diagnostics if it still fails. The native diagnostic refinement is outside this Build 69 commit.
