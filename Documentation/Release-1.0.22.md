# WrapPin 1.0.22 (Build 74)

[简体中文](Release-1.0.22.zh-CN.md)

This release improves background keep-alive startup and recovery from interrupted location connections.

- Start keep-alive while the app is in the foreground; recheck requests without recent location callbacks on foreground activation.
- An active session can rebuild its connection up to three consecutive times, after 1, 2 and 4 seconds, using the latest coordinates. One minute of stable activity resets the retry budget.
- Freeze route progress during reconnect and preserve the user's paused state.
- Stop, reset and real-location restoration cancel reconnect. Authentication errors and persisted unconfirmed sessions still require user action.
- Diagnostics include the last background callback time and reconnect status/count.

## Packages

[Download v1.0.22](https://github.com/suversal/WrapPin/releases/tag/v1.0.22). Both are unsigned IPAs for iOS/iPadOS 18.0+.

- Standard: for SideStore and other self-signing; requires an external device tunnel such as LocalDevVPN.
- Tunnel: includes the device tunnel; matching app/extension profiles with Packet Tunnel entitlements are required. Free accounts should use Standard.

Upgrade the same edition with the existing signing identity; pairing normally need not be reset. Pairing workflows are unchanged.

## Verification and limits

All 13 offline checks passed, including keep-alive, retry policy, production coordinator fault injection and route continuity. Both Debug device builds, Release archives and package checks passed. Checks cover version, arm64, minimum OS, iPhone/iPad families, extension layout, unsigned state, legal resources, ZIP integrity and byte-for-byte archive agreement. The native engine is unchanged, overseas-search configuration is retained and telemetry remains unconfigured.

Build 74 physical-device installation and long locked-screen/background acceptance remain pending. Fault injection does not establish that all reported device failures have been reproduced or fixed. Background operation still depends on system scheduling, location authorization and the device tunnel.

See the [package receipt](../Releases/LocationContinuity-build74/receipt.json) for sizes and SHA-256 values.
