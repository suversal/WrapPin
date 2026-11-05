# Changelog

All notable public changes to WrapPin are recorded here.

## [Unreleased] — 1.0.21 Build 69 candidate

- Target iOS 26.0 in both editions, with computer-generated RPPairing import on iOS 26 and the existing PIN pairing on iOS 27.
- Add explicit XML paste, actionable import validation and safe replacement behavior.
- Both Debug builds, Release archives, all 11 offline checks and package checks passed; the user reported initial Standard success on iOS 26.5, while restoration, routes, background operation, Tunnel and other OS versions still need acceptance. See the [candidate notes](Documentation/Release-1.0.21.md).

## [1.0.20] - 2026-10-28

### Added

- Overseas place search: a Domestic / Overseas switch in the search box sends overseas queries to Geoapify (OpenStreetMap data) because mainland Apple Maps data has few overseas places. Up to five candidates appear with precision labels; a leading Chinese country name limits results to that country, and house-number queries show non-building results as approximate. Searches run only on submit, with 50 per iPhone per day and a seven-day on-device cache.
- Pasted coordinates with full-width commas, spaces, degree signs with N/S/E/W, 北纬/东经 or degrees-minutes-seconds.

### Changed

- Map error messages fade after a few seconds, can be tapped away and animate in and out. When a search finds nothing, WrapPin suggests pasting coordinates.
- Copy Diagnostics includes the underlying error kind and code of a failed location session. The connection check no longer says the pairing is valid.

### Known limitations

- In mainland China overseas search may need a proxy to reach Geoapify. Many street addresses, especially in Japan, are not found; paste coordinates instead.
- All installations share one free Geoapify quota.
- Overseas points inside the mainland coordinate-mode envelope, such as Seoul, are still recommended GCJ-02.

### Tested

- Both schemes passed Debug and Release builds, all ten check scripts passed, and all twelve Rust unit tests passed. Both unsigned IPA files passed package identity, version, extension and ZIP-integrity checks.
- The maintainer used overseas search on a physical iPhone with the Build 64 test package; the two issues found were fixed. Builds 65 and 66 have not been installed on a device.

## [1.0.19] - 2026-10-20

### Added

- App Shortcuts: **Simulate Favourite Place** and **Stop and Restore Real Location**, available in the Shortcuts app, Spotlight, Siri and automations. Both open WrapPin; stopping waits for device confirmation and reports an unconfirmed clear as a failure. Settings → Shortcuts explains them and opens WrapPin in the Shortcuts app.
- Stash, Egern, Quantumult X and sing-box as tunnel handoff apps. Stash and Egern are asked to start; Quantumult X and sing-box are only opened.
- Coordinate mode memory for saved and recent places, and for new places within 100 km of the last manual change. Reset WrapPin clears it.

### Known limitations

- Shortcuts do not start while an interrupted simulation is pending, a route simulation is running, or setup and pairing are incomplete. Recovery remains manual.
- The existing mobile-data limitation applies to third-party tunnel apps; use Wi-Fi with them.

### Tested

- Both schemes passed Debug and Release builds, all eight check scripts passed, and all ten Rust unit tests passed. Both unsigned IPA files passed package identity, App Shortcuts metadata, extension and ZIP-integrity checks.
- The maintainer reported that the 1.0.18 Build 62 test package, with the same feature code, worked on a physical device, including both shortcuts, without recording individual cases. Build 63 changes only the version and has not itself been installed on a device.

## [1.0.18] - 2026-10-15

### Fixed

- Initial and active coordinate writes now have a 15-second timeout, preventing an unresponsive device from leaving Stop waiting indefinitely. An unconfirmed stop preserves the recovery entry.
- Interrupted sessions retain the last location and route progress after coordinate-write or restore failures. The recovery entry appears immediately, allowing the user to continue simulation or restore the real location without restarting the app. An existing unconfirmed record also survives a failed connection retry or an attempt to start at a new place.
- Temporary Core Location errors no longer stop background location updates. Returning to the foreground reconciles authorization and keep-alive state; the home screen warns when keep-alive is unavailable.

### Added

- Optional **Reduce background location indicator**, off by default. Only explicitly enabling it requests an upgrade to Always authorization; the indicator is hidden only while the preference is on and authorization is Always. Connection Health shows the authorization level and indicator state.

### Improved

- Clarified that the tunnel handoff list chooses which app to open and does not limit compatible software. Other correctly configured device-tunnel apps can be enabled manually.

### Known limitations

- Recovery is manual, with no automatic reconnection or guarantee of uninterrupted background connectivity. Force-quitting WrapPin ends the simulation connection even if the VPN remains connected.
- Coordinate writes and location clearing each have a 15-second deadline. Stop can approach 30 seconds when a write completes near its deadline and clearing then times out, provided iOS allows the app to execute.
- iOS controls the final indicator display and may periodically remind the user about background location use. Turning the preference off does not revoke Always authorization; it can be changed in system Settings. Keep-alive coordinates are neither saved nor uploaded.
- The existing mobile-data limitation through Shadowrocket, Surge and Loon is unchanged; use Wi-Fi with these apps.

### Tested

- Both schemes passed Debug and Release builds, all eight check scripts passed, and all ten Rust unit tests passed. Both unsigned IPA files passed package identity, resource, architecture, extension and ZIP-integrity checks.
- The maintainer reported that the main features passed physical-device testing with Build 60, without recording individual cases. Build 61 has the same feature code and has not itself been installed on a device.

## [1.0.17] - 2026-10-11

### Improved

- The selected-location card on the map can be collapsed to leave more of the map free for choosing a point ([#29](https://github.com/suversal/WrapPin/issues/29)). Swipe down on the card or tap its handle to collapse it; swipe up or tap the handle again to expand it. WrapPin remembers the choice.
- While collapsed, the card keeps the place, the favourite and clear buttons and the main button, and shows the simulation coordinate mode as a small menu so it can still be switched. The mode selector with its hint, **Copy coordinates**, the route preview buttons and the routine status line are hidden until the card is expanded. Pairing, connection, failure and restore messages always stay visible.

### Known limitations

- At accessibility text sizes the card scrolls, so it collapses through the handle only, not by swiping.
- The route preview card cannot be collapsed.

### Tested

- The maintainer tried the collapse and expand behaviour on a physical iPhone with local test Builds 53 and 54; the individual cases were not recorded. Build 55 has the same feature code as Build 54 and has not itself been installed on a device.

## [1.0.16] - 2026-10-10

### Added

- Added Surge as a tunnel handoff choice, available in the Standard edition and in the Tunnel edition when its built-in tunnel is not in use. WrapPin uses Surge's official `surge:///start` action when the paired-device channel is unavailable.
- Documented Surge 5.23+'s official on-device developer-services configuration using `tun-included-routes` and IP Rewrite for `10.7.0.1`, in [English](Documentation/SurgeIntegration.md) and [Chinese](Documentation/SurgeIntegration.zh-CN.md).
- Added Loon as a tunnel handoff choice, available in the same cases. WrapPin uses Loon's official `loon://on` action when the paired-device channel is unavailable, and the Loon build 1007+ `include-tun` and IP Rewrite settings are documented in [English](Documentation/LoonIntegration.md) and [Chinese](Documentation/LoonIntegration.zh-CN.md).

### Improved

- Generalized external-tunnel mobile-data guidance and connection diagnostics so they apply to Shadowrocket, Surge and Loon.
- Shadowrocket is now asked to connect its VPN through `shadowrocket://connect` instead of only being opened, matching Surge and Loon. Its settings footer follows the same wording as the other tunnel apps, and the required **Include Route 10.7.0.1/32** setting is documented in [English](Documentation/ShadowrocketIntegration.md) and [Chinese](Documentation/ShadowrocketIntegration.zh-CN.md).

### Known limitations

- WrapPin cannot inspect another app's VPN state, so Shadowrocket, Surge and Loon must still be configured and enabled independently.
- Shadowrocket, Surge and Loon do not return to WrapPin on their own after starting; switch back manually.
- On mobile data, the device connection through Shadowrocket, Surge or Loon is unreliable. This is a known issue that is not fixed in this release; use Wi-Fi with these apps, or LocalDevVPN on mobile data.

### Tested

- The maintainer installed Build 52 of both editions on a physical iPhone and confirmed the handoff to Shadowrocket, Surge and Loon. The contributor's earlier Build 49 completed a location session through Surge 5.102.0 and through LocalDevVPN.

## [1.0.15] - 2026-10-08

### Fixed

- Four connection failure messages named LocalDevVPN even when Shadowrocket or the built-in tunnel was in use. They now refer to the device tunnel.

### Known limitations

- Build 48 has not been installed on a device, and this wording change was not device-tested on its own. The rest of the feature code is the same as 1.0.14.

## [1.0.14] - 2026-10-08

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

### Known limitations

- Times on route options use the simulated speed, not live traffic. Resuming an interrupted route replans with the suggested route rather than a previously chosen alternative.
- A few connection failure messages still name LocalDevVPN when Shadowrocket or the built-in tunnel is in use.
- Build 47 was rebuilt after the version change and has package-level checks only; the same feature code passed device testing as Build 46 in both editions.

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
