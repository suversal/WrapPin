# WrapPin Privacy

[简体中文](Privacy.zh-CN.md)

WrapPin is designed to keep sensitive location and pairing information on the iPhone.

## Information that stays on the iPhone

WrapPin does not send:

- Coordinates, selected places or addresses.
- Search text, favourites or location history.
- Walking routes, route progress or pace.
- Pairing records, pairing PINs or cryptographic material.
- Apple ID, device name or personal details.
- Connection diagnostics or support reports.

Pairing records are stored in the device-only Keychain. App preferences and saved places remain in local app storage.

The Simulate Favourite shortcut makes favourite names and place descriptions available to the Shortcuts app and Siri on this iPhone so a favourite can be chosen. Coordinates are not provided to them, and the shortcuts add no network request or statistics event.

Overseas place search is optional and only appears in builds that include a Geoapify API key. When you switch the search box to **Overseas** and tap Search, the search text is sent to [Geoapify](https://www.geoapify.com/privacy-policy/) over HTTPS to find candidates; nothing is sent while typing, in domestic mode, or for pasted coordinates. Geoapify can observe connection metadata such as the requesting IP address. The request contains no coordinates, pairing data, device name or diagnostics. Recent results are cached on the iPhone for seven days and a daily search count is stored locally; neither is uploaded or included in usage statistics.

When the app opens, it requests the latest public release metadata from GitHub to check for an update. The request does not include location, pairing or diagnostic data. As with any network request, GitHub can observe connection metadata such as the requesting IP address.

## Optional background location indicator preference

**Settings → Background Location Indicator → Reduce Background Location Indicator** is optional and off by default. The default session flow continues to request only While Using the App access and display the blue background-location indicator.

Only switching this preference on explicitly requests an upgrade to Always access. If access has not been requested, WrapPin requests While Using the App first and then requests the upgrade when that permission is granted. Loading the saved choice, opening the app, starting a session and returning to the foreground never request an Always upgrade. If iOS no longer offers the upgrade prompt, you declined it, or you chose Allow Once, use the provided iOS Settings link to choose Always. The preference remains separate from the permission granted by iOS.

WrapPin requests a hidden indicator only while the preference is on and authorization is Always; otherwise it requests a visible indicator. iOS controls the final appearance. Dynamic Island behavior on iOS 27 and continuity during locking or extended background use still require physical-device verification. iOS may periodically remind you about background location access. Turning the preference off restores the indicator but cannot revoke Always access; change the permission back to While Using the App in iOS Settings if desired. Ending a simulation still stops the background location updates.

The preference is stored in local UserDefaults. Coordinates received by the background keep-alive are never saved or uploaded. Selected simulation locations and recovery records remain local as before. This option adds no statistics event or location collection, and does not change the optional anonymous statistics below. The privacy manifest remains unchanged: no location data is collected, and its existing UserDefaults declaration also covers this local preference.

## Optional anonymous usage statistics

The app offers **Share Anonymous Usage Statistics**. It is off by default. New users see the switch before finishing setup, and nothing is sent unless they affirmatively switch it on. Existing installations keep their previously saved choice when upgrading. The setting can be changed at any time under **Settings → Privacy**.

When sharing is enabled, the app may count:

- A participating installation opening the app or returning it to the foreground.
- Onboarding or pairing being completed.
- A fixed-location, walking or driving session successfully starting.
- A location being updated during an active session.
- The app version and build associated with an event.
- An approximate event time added by TelemetryDeck.

These are activity signals only. They do not contain the location, route or other user content involved in an action.

## Installation counting

The app creates a random identifier for the installation in its local app storage. It sends an irreversible SHA-256 hash so participating installations can be counted approximately without using a name, Apple ID, advertising identifier or hardware identifier. No per-launch session identifier is sent.

Turning sharing off immediately prevents future events and deletes the locally stored identifier. Turning it on again creates a new identifier, so activity before and after the opt-out cannot be linked by WrapPin. Turning sharing off cannot withdraw anonymous events already received by TelemetryDeck. Those events do not contain a location or personal identity.

Statistics therefore describe participating installations, not every download or every person using WrapPin.

## Service and data minimisation

WrapPin sends its fixed event list directly to TelemetryDeck's Ingest API over HTTPS. It does not embed a third-party analytics SDK, which prevents an SDK from automatically adding device metadata. TelemetryDeck states that it does not store IP addresses. It also states that cold-storage event retention is roughly 7–10 years and that an exact deletion schedule is not guaranteed. Its privacy information is available at [telemetrydeck.com/docs/guides/privacy-faq](https://telemetrydeck.com/docs/guides/privacy-faq/).

If the release has no TelemetryDeck App ID and namespace configured, the statistics client sends nothing.

## Changes

Any future change to the information collected must be reflected in this document and in the in-app **What Is Shared** screen before release.

Custom route points and the next waypoint index are stored locally with interrupted-session recovery. Imported GPX files are parsed locally; their contents and custom routes are never included in analytics or uploaded for route planning. The map provider may still receive map tile requests.
Route-point place searches use the same providers as the main map. Search terms are sent to the selected provider; the assembled custom route is not uploaded. Pasting coordinates into the route picker resolves them locally without reverse geocoding.
