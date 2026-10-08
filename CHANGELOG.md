# Changelog

All notable public changes to WrapPin are recorded here.

## [Unreleased]

### Added

- Walking and driving previews now offer up to three routes when Apple Maps suggests alternatives. Choose one on the preview card or tap it on the map before starting; time and distance update for the chosen route.

### Improved

- The tunnel edition now checks the latest public GitHub release and shows update notices, like the standard edition. Both editions are attached to the same release.
- Stopping while a location session is still connecting now takes effect at once instead of waiting for the remaining connection steps, and no longer applies the selected location briefly before clearing it.

### Fixed

- Failure stages in Connection Health and in optional anonymous statistics were reported as unknown when the app ran in Simplified Chinese, and for two device-discovery failures in any language. The location engine now reports a stage code, so classification no longer depends on the wording or language of a message.
- A stop that the iPhone did not confirm now shows its message in the app's language.
- After Stop & Restore, the current-location button could centre the map on the last simulated place instead of the iPhone's real position. The map now ignores location fixes that iOS marks as simulated and waits for a real one.
- Device Setup, the introduction and the in-app guide named LocalDevVPN even when Shadowrocket was the selected tunnel app. They now name the selected app, and the tunnel-app button in Device Setup and Connection Health opens that app when it is installed or its App Store page when it is not.
- Device Setup showed its pairing steps, the “Before connecting” list and the fingerprint labels in English when the app ran in Simplified Chinese.

## [1.0.13] - 2026-10-04

### Added

- Added a separate tunnel edition with a built-in Packet Tunnel for the paired-device connection. It starts with a location session and stops after the real location is restored; a manually started tunnel stays on until stopped. It needs signing profiles with Packet Tunnel permission for the app and its extension, uses its own App ID and can be installed beside the standard edition.

### Improved

- The standard edition is unchanged in behaviour and contains no tunnel code or extension.
- Both editions are now built from one source tree and one version file with `scripts/package-ipa.sh`.

### Known limitations

- The tunnel edition does not show update notices yet.

## [1.0.11] - 2026-09-23

### Improved

- Changed custom walking-speed adjustment from 0.5 km/h to 0.1 km/h steps.
- Changed driving-speed adjustment from 5 km/h to 1 km/h steps.

### Known limitations

- This release changes only the speed-control increments. Build 31 still needs an independent SideStore installation and physical-iPhone interaction check.

## [1.0.10] - 2026-09-22

### Added

- Added a choice between WGS84 and GCJ-02 coordinate handling for fixed location simulation, including map selection and manual coordinate entry. The modes can be switched when a location appears offset.
- Check the latest public GitHub release on launch and show a dismissible update notice when a newer version is available.

### Improved

- Added an explicit close button and compact controls to walking and driving route previews; sized the card to its content.
- Kept map controls on the existing material appearance after trying and removing Liquid Glass styling.
- Added a location callback probe to Connection Health for investigating coordinate mismatches.

### Known limitations

- Neither coordinate mode is guaranteed to match every map display or third-party app. Route simulation and other apps can have separate behavior. The final Build 30 still needs an independent iPhone installation and visual check.

## [1.0.9] - 2026-09-22

### Added

- Added an optional custom walking-route speed from 1 to 12 km/h in 0.5 km/h steps, while keeping the three walking presets.

### Improved

- Restore a custom walking speed when resuming an interrupted route, without breaking older walking records.
- Give the main Settings rows consistent SF Symbol icons and alignment, including the selectors, privacy control, build details and reset action.
- Clarify that developer location simulation does not change Apple Watch, eSIM, carrier or satellite feature eligibility.

### Known limitations

- This release does not claim to fix reported coordinate offsets or make third-party apps accept simulated locations.

## [1.0.8] - 2026-09-22

### Added

- Added a Settings choice for LocalDevVPN or Shadowrocket as the tunnel app to open when WrapPin cannot reach the paired iPhone.

### Improved

- Check the paired-device connection before opening the selected app on Wi-Fi, and avoid another app handoff once that connection is reachable for the current attempt.
- Keep LocalDevVPN's existing cellular connect-and-return flow. Give Shadowrocket users a Wi-Fi recommendation when its device connection cannot be established on cellular.
- Clarified connection guidance and diagnostics: WrapPin checks the paired-device tunnel, not another app's VPN switch.

## [1.0.7] - 2026-09-21

### Added

- Added driving-route preview and constant-speed location simulation from 5 to 240 km/h.

### Improved

- Preserve route mode and speed when recovering an interrupted session, while continuing to read earlier walking recovery records.
- Speed up point lookup on long routes and avoid reversing one-way driving routes at arrival.

## [1.0.6] - 2026-09-17

### Improved

- Kept on-device pairing alive while switching to Settings without making pairing depend on `BGTaskScheduler` registration.
- Started the native location worker directly and used Core Location only as a privacy-preserving background keep-alive while a simulation is active.
- Added a background-session status to Connection Health so permission and delivery problems are visible without collecting coordinates.

### Fixed

- Avoided SideStore runtime bundle-identifier changes blocking pairing or location startup through mismatched background-task identifiers.

## [1.0.5] - 2026-09-15

### Improved

- Added locale-aware Apple Maps reverse geocoding with one retry for transient or empty results.
- Re-resolve older unresolved favourites and history entries when they are selected, while preserving custom favourite names.
- Show an exact latitude and longitude when Apple Maps cannot provide a readable address.

### Fixed

- Prevented temporary “Finding nearby address…” text from being saved by disabling location actions until address resolution completes.
- Ensured an empty reverse-geocoding response reaches a stable fallback instead of leaving the loading text indefinitely.
- Documented the reliable local-file SideStore installation flow to avoid remote filename and bundle-identifier mismatches.

## [1.0.4] - 2026-09-15

### Changed

- Increased the X profile icon to match the visual scale of the other Community rows.
- Changed the Simplified Chinese X profile label from “follow我” to “关注我”.
- Updated the README with the current feature set, validation status and release progress.

## [1.0.3] - 2026-09-15

### Added

- Added an X profile link to the Community section so users can follow the WrapPin maintainer directly from Settings.

## [1.0.0] - 2026-09-14

First stable WrapPin release, based on Roam Control 0.9.2 Beta 3 and maintained as an unofficial community fork.

### Added

- Complete Simplified Chinese interface, connection guidance, diagnostics and documentation.
- Fixed-location and walking-route simulation with favourites, history, recovery and real-location restoration.
- Dedicated light and dark WrapPin app icons.
- In-app links for GitHub Stars, bug reports and feature requests.

### Improved

- Kept long-running on-device pairing alive while iOS continued-processing tasks remain active.
- Rejected USB and Wi-Fi `169.254.x.x` link-local service addresses and preferred the LocalDevVPN endpoint for saved sessions.
- Added clearer connection stages, endpoint sources, retry guidance and privacy-preserving diagnostics.
- Kept Apple signing identifiers, analytics credentials and other private build values outside the repository.
- Unified the project directory, Xcode project, target, scheme, app, native bridge, bundle identifier, URL scheme, scripts and documentation under the WrapPin name.

### Validation

- Simplified Chinese localization coverage and native failure classification checks pass.
- The native Rust bridge builds for arm64 iPhone and arm64 Apple Silicon simulator.
- Unsigned Release build and IPA integrity checks pass for version `1.0.0` Build `1`.
- Earlier candidates passed physical-device installation and core usage testing; the final 1.0 package should still be installed once before public release.

[Unreleased]: https://github.com/suversal/WrapPin/compare/v1.0.11...HEAD
[1.0.11]: https://github.com/suversal/WrapPin/releases/tag/v1.0.11
[1.0.10]: https://github.com/suversal/WrapPin/releases/tag/v1.0.10
[1.0.9]: https://github.com/suversal/WrapPin/releases/tag/v1.0.9
[1.0.8]: https://github.com/suversal/WrapPin/releases/tag/v1.0.8
[1.0.7]: https://github.com/suversal/WrapPin/releases/tag/v1.0.7
[1.0.6]: https://github.com/suversal/WrapPin/releases/tag/v1.0.6
[1.0.5]: https://github.com/suversal/WrapPin/releases/tag/v1.0.5
[1.0.4]: https://github.com/suversal/WrapPin/releases/tag/v1.0.4
[1.0.3]: https://github.com/suversal/WrapPin/releases/tag/v1.0.3
[1.0.0]: https://github.com/suversal/WrapPin/releases/tag/v1.0.0
