# Build and Release Guide

This guide covers WrapPin's development builds and the planned IPA workflow.

## Current release tracks

- Marketing version: `1.0.13`, Build `41`, for both editions
- Standard edition (SideStore): bundle identifier `com.suversal.wrappin`
- Tunnel edition: bundle identifier `com.suversal.wrappin.selfsigned`; extension: `com.suversal.wrappin.selfsigned.tunnel`
- Minimum deployment target: iOS 27
- Supported device family: iPhone

The version and build are shown in **Settings** inside the app. The built date and time come from the timestamp embedded for that packaged build.

## Version and build rules

WrapPin uses two separate numbers:

- The **version** describes the public release. Increase it for each subsequent stable release.
- The **build** identifies one exact install. Increase it once for every build installed on a test iPhone or packaged as an IPA.

Ordinary compile checks do not consume a build number. Build numbers must never move backwards for a later install or upload.

Both values, and the build timestamp, are stored once in `Configuration/Version.xcconfig`:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`
- `WRAPPIN_BUILD_TIMESTAMP`

The Standard app, the Tunnel app and the Packet Tunnel extension all read that file. Do not set these values again in a target's build settings; the extension must always match the app that embeds it.

## Build in Xcode

1. Open `WrapPin.xcodeproj`.
2. Select **WrapPin Standard** for the SideStore edition or **WrapPin Tunnel** for the self-sign edition.
3. Select the connected iPhone.
4. Open **Signing & Capabilities** and confirm the development team.
5. Press **Run**.

The simulator can validate most interface states, but it cannot perform the real RPPairing handshake or start a location session.

## Native pairing engine

The prebuilt `Frameworks/WrapPinPairingFFI.xcframework` should be committed with both arm64 iPhone and arm64 Apple Silicon simulator slices.

Only rebuild it after changing `Native/WrapPinPairingFFI`. The rebuild requires Rust targets for:

- `aarch64-apple-ios`
- `aarch64-apple-ios-sim`

Run `scripts/build-pairing-engine.sh` from the project directory. Confirm the app still builds for both a physical iPhone and the simulator afterwards.

## Archive preparation

Before creating an archive:

1. Finish the regression checklist.
2. Increase `CURRENT_PROJECT_VERSION` for the archive.
3. Confirm the public version.
4. Use the Release configuration.
5. Confirm the app icon and display name.
6. Set and verify the build timestamp.
7. For a public build, set the TelemetryDeck App ID and namespace and confirm no secret token is present.
8. Confirm `WrapPinPairingFFI.xcframework` is embedded and signed.
9. Confirm the app bundle contains `WrapPin-LICENSE.txt`, `THIRD_PARTY_NOTICES.txt` and `idevice-LICENSE.txt`.
10. Build once for a physical iPhone.

Then select **Any iOS Device (arm64)** and choose **Product → Archive**. Xcode opens Organizer after a successful archive.

## IPA and SideStore

Both editions are released from the same commit and attached to the same GitHub Release. **WrapPin Standard** is the SideStore package and contains no tunnel code. **WrapPin Tunnel** embeds `WrapPinTunnel.appex` and needs signing profiles for both the app and extension with Packet Tunnel permission. See [BuiltInTunnelResearch.zh-CN.md](BuiltInTunnelResearch.zh-CN.md) for the signing and device test sequence.

Run `scripts/package-ipa.sh all` to package both editions. For each one it creates a Release archive with `CODE_SIGNING_ALLOWED=NO`, checks the app and extension identities, packages `Products/Applications/*.app` under `Payload/` with `ditto`, prints the SHA-256 and refuses to overwrite an existing build number; `standard` and `tunnel` package one edition. The tunnel edition's distinct bundle ID and `wrappintunnel://` return scheme prevent it from replacing or receiving callbacks meant for the standard edition. It has separate app storage and pairing state. To sign it, the paid team needs matching profiles for both `WRAPPIN_TUNNEL_BUNDLE_IDENTIFIER` and that ID plus `.tunnel`.

For personal SideStore installation:

1. Use the verified IPA from `Releases`, or create a new one from a Release archive.
2. Move the IPA to Files or another location SideStore can access.
3. Open SideStore, choose the IPA and allow SideStore to sign/install it with the configured Apple ID.
4. Keep Developer Mode enabled.
5. Complete WrapPin's pairing on the installed copy if its signing identity gives it a new Keychain container.

SideStore re-signing and Apple's free-account limits can affect expiry, app identifiers and available entitlements. The final IPA must therefore be tested as a SideStore install rather than assuming an Xcode-installed build is equivalent. With a free Apple Account, SideStore normally refreshes the signed installation within Apple's seven-day development period.

Build 37 Standard passed package checks but was reported to reach an iOS “Unable to Verify App” developer-trust prompt after SideStore installation. That is a failed device-acceptance gate. The unsigned IPA cannot establish whether the final SideStore certificate/profile was trusted or whether the phone reached Apple's verification service; compare other apps signed by the same SideStore account and inspect the device's developer-verification state before rebuilding or deleting app data.

Do not treat an Xcode Debug `.app` folder renamed to `.ipa` as a release package. Use the verified Release archive/package workflow.

## Privacy statistics configuration

Optional statistics are sent directly to TelemetryDeck's Ingest API. WrapPin does not embed its SDK and permits only the event names and app/build values defined in `UsageAnalyticsService.swift`.

Three build settings configure a public or locally signed build:

- `WRAPPIN_BUNDLE_IDENTIFIER`
- `WRAPPIN_TUNNEL_BUNDLE_IDENTIFIER`
- `WRAPPIN_TELEMETRY_APP_ID`
- `WRAPPIN_TELEMETRY_NAMESPACE`

The tracked `Configuration/Local.xcconfig` keeps the public bundle identifier and leaves the TelemetryDeck ingestion identifiers blank. Copy `Configuration/Local.private.xcconfig.example` to the ignored `Configuration/Local.private.xcconfig` to override the bundle identifier for a personal team, set `DEVELOPMENT_TEAM`, or configure both TelemetryDeck values for a release. The telemetry values are ingestion identifiers, not an account password or API token. Without both values, the client sends nothing. Keeping the live destination and signing identity outside the public project prevents forks from accidentally adding data to WrapPin's dashboard or inheriting the repository owner's Apple team.

Before packaging a configured build, inspect the event structure, confirm the privacy disclosure still matches it, and run the privacy rows in the regression checklist. Never add coordinates, place text, searches, saved locations, routes, pairing material, device names, user-supplied text or diagnostic content to an event.

## Release records

For each distributed build, record:

- Version and build number.
- Date and time created.
- Xcode and iOS versions used.
- Signing method.
- Device used for testing.
- Regression checklist result.
- Known issues.

This makes a problem report traceable to the exact binary shown in WrapPin's Settings screen.
