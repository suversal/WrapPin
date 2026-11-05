# WrapPin User Guide

WrapPin lets you choose where your iPhone reports its location. You can hold one fixed place or simulate movement along an Apple Maps walking or driving route.

## First-time setup

On iOS 26, first [create and import an RPPairing file with a computer](iOS26Pairing.md). The six-digit pairing steps below apply to iOS 27 or later. Standard needs an external device tunnel; Tunnel asks to add its built-in VPN configuration.

You need your physical iPhone and Developer Mode. Standard also needs LocalDevVPN or another configured device tunnel; Tunnel uses its built-in tunnel.

1. Open WrapPin and complete the three-page introduction.
2. On **Device Setup**, tap **Pair This iPhone**.
3. Allow Local Network access when iOS asks.
4. Open **Settings → Privacy & Security → Developer Mode → Pair with WrapPin**.
5. Enter the six-digit code shown by WrapPin.
6. Standard: install LocalDevVPN from Device Setup if it is not already installed. Tunnel: allow its built-in VPN configuration when starting a location.
7. Standard: open LocalDevVPN and connect its local tunnel. Tunnel starts its own tunnel when needed.

Pairing is normally required only once. WrapPin stores the pairing record in this iPhone's Keychain and does not upload it.

## Choose a location

Use any of these methods:

- Type a place into the search box and choose a live result.
- Enter coordinates such as `51.50740, -0.12780`. Pasted formats such as `35.6586° N, 139.7454° E`, `北纬35.6586°，东经139.7454°` and degrees-minutes-seconds also work.
- Tap anywhere on the map to drop a precise pin.
- Open the heart/list button to choose a favourite or recent location.
- Use **Resume** when WrapPin offers the last used location.

Apple Maps data on iPhones in mainland China often has no overseas places. When a build includes overseas search, tap **Domestic** at the end of the search box to switch to **Overseas**, type the place and tap Search. Starting the query with a country name in Chinese, such as 法国巴黎 or 日本东京塔, limits results to that country. Up to five candidates appear, each labelled with its precision (house number, place, street, area, city…); an orange label means only an approximate position was found, so check it before simulating. For a query with a house number, only a result at that house number is shown as exact. Overseas search connects to Geoapify's servers outside China; in mainland China it may not be reachable without a proxy, in which case paste coordinates instead. Overseas results come from Geoapify using OpenStreetMap data, and street addresses are often missing, especially in Japan. Each iPhone can run 50 overseas searches a day; repeating a recent search uses the saved result. If a place cannot be found, paste its coordinates instead.

Choosing a search result clears the search box automatically. The close button on a selected-location card clears a dropped pin or selection. The copy button copies the readable place and address.

To see more of the map, swipe down on the selected-location card or tap the handle at its top to collapse it; swipe up or tap the handle again to expand it. WrapPin remembers the choice. While collapsed, the card shows the simulation coordinate mode as a small menu next to the address, and the route preview and copy buttons are hidden.

## Start a fixed location

1. Choose the location.
2. Tap **Start Location**.
3. Follow the LocalDevVPN guidance if it appears.
4. Wait for the status to show that the location is active.

There is no separate confirmation step after choosing a location.

To move an active session, choose another place and tap **Update Location**. WrapPin keeps the existing secure session and changes the location directly.

Tap **Stop & Restore** when you want iOS to return to the real location, then confirm the choice. Keep WrapPin open while it restores the real location.

## Wi-Fi connection flow

**Tunnel App** chooses the app WrapPin opens for tunnel setup; the list is not a list of all compatible apps. Other VPN or proxy apps can also be used if they provide a correctly configured device tunnel. Configure and enable their tunnel manually before returning to WrapPin. Compatibility depends on reaching the paired iPhone's device connection, not on the app appearing in this list.

**Settings → Tunnel App** selects LocalDevVPN (the default), Shadowrocket, Surge, Loon, Stash, Egern, Quantumult X or sing-box. On Wi-Fi, WrapPin checks whether it can reach the paired iPhone and opens the selected app only if that connection fails. On mobile data, LocalDevVPN retains its original connect-and-return startup flow, so it still opens once; the other apps are opened only after the device connection cannot be established, and those with a start link are also asked to turn on their VPN. WrapPin cannot inspect any of these apps' VPN switches directly.

With Shadowrocket selected, WrapPin asks it to connect its VPN through `shadowrocket://connect`; return to WrapPin manually afterwards. Shadowrocket provides the device connection only when **Include Route 10.7.0.1/32** is turned on in its Settings, as described in [Shadowrocket setup](ShadowrocketIntegration.md). If it cannot connect over mobile data, use Wi-Fi. If Wi-Fi also fails the connection check, keep LocalDevVPN as the default.

With Surge selected, WrapPin asks Surge to start its selected configuration through `surge:///start`; return to WrapPin manually afterwards. Surge provides the device connection only on Surge iOS 5.23.0 or later with the route and IP Rewrite settings in [Surge iOS setup](SurgeIntegration.md). If it cannot connect over mobile data, use Wi-Fi.

With Loon selected, WrapPin asks Loon to turn on its VPN through `loon://on`; return to WrapPin manually afterwards. Loon provides the device connection only on build 1007 or later with the `include-tun` and IP Rewrite settings in [Loon setup](LoonIntegration.md). If it cannot connect over mobile data, use Wi-Fi.

With Stash or Egern selected, WrapPin asks the app to turn on its VPN through `stash://start` or `egern:/start`; return to WrapPin manually afterwards. Quantumult X and sing-box have no link that turns on their VPN, so WrapPin only opens them; turn the VPN on yourself and return. All four must be configured to send connections to `10.7.0.1` back to this iPhone; for example, sing-box 1.12 or later needs `loopback_address: 10.7.0.1` in its TUN inbound. After setup, use **Settings → Connection Health** to confirm the device connection.

When Wi-Fi is connected, WrapPin looks for the paired iPhone through a compatible device tunnel immediately. LocalDevVPN remains the supported default.

- If LocalDevVPN is already connected, the location should start without mobile-data instructions.
- If its tunnel is unavailable, WrapPin opens LocalDevVPN automatically and returns to the pending session.
- If the connection still is not visible, the **Still Connecting** screen offers **Try Again** and **Open LocalDevVPN**.

Do not choose **I'm Using Mobile Data** while connected to Wi-Fi.

## Mobile-data connection flow

When the iPhone is using 4G or 5G with LocalDevVPN:

1. Start the selected location.
2. WrapPin opens LocalDevVPN if necessary.
3. When **Turn Mobile Data Off** appears, temporarily switch mobile data off.
4. Return to WrapPin. It detects the local iPhone connection automatically.
5. If automatic detection does not continue, tap **Continue** as the manual backup.
6. When **Turn Mobile Data Back On** appears, restore mobile data and tap **Done**.

Only LocalDevVPN startup needs this temporary change. After the secure location session is active, it can continue while mobile data is back on. Apps other than LocalDevVPN do not use this mobile-data-off guidance; if they cannot connect over mobile data, use Wi-Fi instead.

## Walking routes

1. Choose a destination.
2. Tap **Preview Walk**.
3. Check the route, distance, estimated time and arrival time. When Apple Maps suggests several routes, the card lists up to three; choose one there or tap it on the map.
4. Choose a walking pace, or turn on **Custom walking speed** to select 1–12 km/h in 0.1 km/h steps. For cycling or faster travel, use a driving route where suitable.
5. Tap **Start Walking**.

During the walk:

- **Pause** holds the current simulated point.
- **Resume** continues from that point.
- The walk can continue while another app is in front.
- **Stop & Restore** ends the walk and restores the real location after confirmation.

At the destination:

- **Walk Route Back** reverses the journey.
- **New Location** keeps the active connection and lets you choose another destination.
- **Stop & Restore** ends the session and restores the real location.

For UK regional settings, short distances are shown in yards and longer distances in miles.

## Driving routes

Choose a destination and tap **Preview Drive**. Check the road route, then set a constant simulated speed between 5 and 240 km/h in 1 km/h steps before tapping **Start Driving**. The displayed travel time uses that simulated speed, not live traffic. You can pause or resume during the route. At the destination, the simulated position stays active until you tap **Stop & Restore** and confirm that your real location has returned. The app does not reverse driving routes because one-way roads may make the reverse path invalid.

## Map controls

- **Current location** flies to the iPhone's real position and turns the map north-up. It is unavailable while a simulated location is active.
- **Compass** appears after the map is rotated. It shows N, E, S and W; tap it to face north again.
- **Connection status** opens pairing and connection setup.
- **Favourites and history** opens saved places. Swipe an item to delete it; swipe a favourite to rename it.
- **Settings** controls appearance, map style, diagnostics, pairing, feedback, help and reset.

## Feedback

Under **Settings → Feedback**, **Report a Bug** and **Request a Feature** open the matching GitHub form. Do not include pairing records, credentials or private locations in a report.

## Interrupted-session recovery

If a coordinate write or stop cannot be confirmed, recovery options appear in the current run. They also appear after relaunch when an unconfirmed record was saved. The displayed location is the last location you set, not confirmation that it is still active.

- **Resume Location** reconnects to a fixed location.
- **Resume Walking** prepares the remaining route from the most recently saved point.
- **Restore Real Location** reconnects only long enough to clear the simulated location.
- **My Real Location Is Already Back** dismisses the recovery record without reconnecting.

Nothing starts automatically from this screen. A failed retry, including selecting a different location and failing to connect, keeps the previous unconfirmed record. It is removed or replaced only after the device confirms clearing the simulation, a new session becomes active, or you choose to dismiss it. Failed writes save the latest in-memory route point without waiting for the usual save interval.

Coordinate writes and clearing the location each have a 15-second timeout. A write timeout ends the operation without trying to clear over the same untrusted connection. If a write finishes just before its deadline and clearing then times out, stopping can take about 30 seconds while the app is running. An error or timeout does not confirm that the real location has returned; check it after recovery.

## Appearance and accessibility

Settings offers automatic, light and dark appearance plus standard, satellite and hybrid maps. WrapPin follows iOS Dynamic Type, VoiceOver and Reduce Motion settings. At accessibility text sizes, cards and pop-ups can scroll so their controls remain reachable.

## Background sessions

An active location session uses iOS Location Services only as a background keep-alive; the coordinates still come from the native developer simulation service and are never read or stored by the keep-alive. Allow Location access when iOS asks. The blue background-location indicator may appear while a simulation is active. If access is denied, foreground simulation can still work, but continuity after switching apps is not guaranteed. **Settings → Connection Health → Background Session** shows the current keep-alive state. The home screen also warns when an active simulation has no background keep-alive. Returning to the foreground rechecks location access; it does not automatically reconnect the developer simulation session. Temporary Core Location errors leave the update request running.

Swiping WrapPin away in the App Switcher ends its simulation connection. A VPN that still shows Connected does not mean the simulation is still active, and closing WrapPin does not confirm that other apps have acquired a fresh real location. Reopen WrapPin to use recovery options when needed.

The native engine checks the connection through subsequent coordinate writes, normally refreshed every four seconds. This timing and the 15-second write timeout apply while the process can run; they are not a guarantee that a suspended app detects a disconnection within 20 seconds.

### Reduce the background location indicator (optional)

**Settings → Background Location Indicator → Reduce Background Location Indicator** is off by default. Leave it off to keep the existing While Using the App permission flow and indicator behavior. Switching it on requires **Always** location access. Without location authorization, WrapPin requests While Using the App first and then asks for the upgrade. If you previously declined the upgrade, chose Allow Once, or see no upgrade prompt, tap **Open iOS Settings** and select Always. The switch keeps your preference even if permission is not granted; restarting WrapPin, starting a simulation or returning to the foreground does not request an upgrade automatically.

Only the combination of this preference and Always access requests a hidden blue indicator. **Settings → Connection Health → Background Session** shows the authorization level and requested indicator behavior. Changes apply immediately during a running session; lowering permission restores the indicator. iOS determines the final appearance, and Dynamic Island behavior on iOS 27 plus locked-screen and long background continuity still need physical-device validation. This option does not fix a lost device connection.

iOS may periodically remind you that WrapPin uses location in the background. The background keep-alive still does not save or upload received coordinates. Turning the switch off restores the indicator without revoking Always access; you can change permission back to While Using the App in iOS Settings. **Stop & Restore** still stops location updates.

## Anonymous usage statistics

The final introduction page shows **Share Anonymous Usage Statistics** before setup completes. It is off by default and sends nothing unless you choose to switch it on. The choice can be changed at any time under **Settings → Privacy**.

When enabled, WrapPin reports only a small fixed list of activity counts: the app opening or returning to the foreground, app version/build, completed onboarding or pairing, starting a fixed, walking or driving session, updating an already-active location, connection-help prompts, manual retries and successful sessions after retry, and fixed failure-stage, scheduler-reason, operation and recoverable/terminal categories (pairing, location or restoration). No raw error messages are sent. TelemetryDeck adds an approximate event time. WrapPin never includes coordinates, place names, searches, favourites, history, routes, pairing records, PINs, Apple ID, device name or diagnostics.

A random installation identifier is stored in local app storage and irreversibly hashed before sending. No per-launch session identifier is sent. Turning sharing off stops future reporting immediately and removes the local identifier, but it cannot withdraw anonymous events already received by TelemetryDeck. TelemetryDeck says it does not store IP addresses and may retain anonymous events for roughly 7–10 years without guaranteeing an exact deletion date. Counts therefore describe participating installations rather than every installation.

Open **Settings → Privacy → What Is Shared** for the same disclosure inside the app. The complete policy is in [Privacy](Privacy.md).

## Shortcuts

WrapPin adds two ready-made shortcuts to the Shortcuts app; nothing needs to be installed. **Settings → Shortcuts** explains them and opens WrapPin's page in the Shortcuts app.

- **Simulate Favourite**: choose a saved favourite when it runs. WrapPin opens and starts simulating that place with the coordinate mode last used there. The shortcut only starts the request; follow the connection progress in WrapPin.
- **Restore Real Location**: stops the running simulation, or restores the real location after an interrupted one, then waits for the device to confirm before reporting the result.

Pair the iPhone and save at least one favourite first. WrapPin comes to the foreground while a shortcut runs and may open the selected tunnel app if the device connection is unavailable. If a simulation was interrupted, Simulate Favourite asks you to choose restore or continue in WrapPin first and never resolves it on its own; a running route simulation must also be stopped in WrapPin first.

In the Shortcuts app, **Automation** can run a WrapPin action from a personal automation such as Arrive, Leave or Time of Day. With Siri, say “Simulate a favourite with WrapPin” or “Restore my real location with WrapPin”; for the Tunnel edition, use the name WrapPin Tunnel.

## Favourites, history and reset

- Favourites remain until you delete them or reset the app.
- History stores the 30 most recently used locations.
- **Replay Introduction** shows onboarding without deleting anything.
- **Reset WrapPin** removes pairing, favourites, history and preferences, then returns to onboarding.
- Reset also removes the anonymous statistics identifier.
- Resetting WrapPin does not uninstall or reconfigure LocalDevVPN.

## Troubleshooting

### LocalDevVPN says Connected, but WrapPin cannot find the iPhone

Check whether you are using Wi-Fi or mobile data. On Wi-Fi, tap **Try Again**. On 4G or 5G, choose the mobile-data flow and briefly turn mobile data off. If the message mentions an outdated announcement, toggle LocalDevVPN off and on once to create a fresh device announcement.

### The discovered device does not match the paired iPhone

The saved pairing record does not match the device announcement. Toggle LocalDevVPN off and on. If the problem remains, confirm that the record belongs to this iPhone. On iOS 26, [create, validate and import a fresh computer-generated record](iOS26Pairing.md); on iOS 27, repeat on-device pairing.

An invalid saved pairing message can also represent other verification failures. Copy diagnostics before concluding that the record has expired.

### The real location is not visible after stopping

Keep WrapPin open for a few seconds while iOS obtains a fresh GPS result. Tap the current-location button after it becomes available. Also check that Location Services permission is allowed for WrapPin.

### A route session ended unexpectedly

Reopen WrapPin and use the interrupted-session screen. Resume from the last saved point or choose **Restore Real Location**.

### I need a readable support report

Open **Settings → Connection Health**, run the connection check, then use **Share Diagnostics**. The report contains app, iOS and connection state information but no pairing keys or PINs.
