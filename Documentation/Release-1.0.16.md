# WrapPin 1.0.16 (Build 49) test record

## Scope

- Add Surge to the Standard edition's tunnel-app choices.
- Start Surge through its official `surge:///start` URL action when the paired-device channel is unavailable.
- Add the Surge 5.23+ on-device developer-services module and setup guide.
- Keep LocalDevVPN, Shadowrocket and the built-in Tunnel edition behavior intact.

## Candidate

- File: `WrapPin-Standard-1.0.16-build49-unsigned.ipa`
- Bundle ID: `com.suversal.wrappin`
- Architecture: arm64
- SHA-256: `84413dfb8df767a75c2f5c24cdeb2d6170230992e505be03f93d4b66875276ea`
- Signing: unsigned; the tester must sign it with SideStore or another trusted method.

## Completed checks

- Standard and Tunnel edition arm64 iOS 27 builds.
- Unsigned Release archive and IPA packaging.
- ZIP integrity, bundle identity, version/build, arm64 architecture, unsigned state and absence of extensions in the Standard package.
- Tunnel handoff policy, localization coverage, native failure stages, background-session lifecycle, coordinate-mode recovery, route-selection compilation and route-recovery compatibility.

## Device acceptance gate

This candidate has not been installed on a physical iPhone. Do not open an upstream pull request until a signed installation verifies:

1. Surge imports or contains the settings in `WrapPin-Surge.sgmodule`.
2. Selecting Surge in WrapPin and starting a location opens Surge and starts its selected configuration.
3. Returning to WrapPin reaches the paired iPhone and starts the location session on Wi-Fi.
4. Stopping restores the real location.
5. LocalDevVPN and Shadowrocket selections still open their respective apps.
