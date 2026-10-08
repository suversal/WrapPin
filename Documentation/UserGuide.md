# WrapPin User Guide

WrapPin lets you choose where your iPhone reports its location. You can hold one fixed place or simulate movement along an Apple Maps walking or driving route.

## First-time setup

You need your physical iPhone, Developer Mode and LocalDevVPN.

1. Open WrapPin and complete the three-page introduction.
2. On **Device Setup**, tap **Pair This iPhone**.
3. Allow Local Network access when iOS asks.
4. Open **Settings → Privacy & Security → Developer Mode → Pair with WrapPin**.
5. Enter the six-digit code shown by WrapPin.
6. Install LocalDevVPN from the Device Setup screen if it is not already installed.
7. Open LocalDevVPN and connect its local tunnel.

Pairing is normally required only once. WrapPin stores the pairing record in this iPhone's Keychain and does not upload it.

## Choose a location

Use any of these methods:

- Type a place into the search box and choose a live result.
- Enter coordinates such as `51.50740, -0.12780`.
- Tap anywhere on the map to drop a precise pin.
- Open the heart/list button to choose a favourite or recent location.
- Use **Resume** when WrapPin offers the last used location.

Choosing a search result clears the search box automatically. The close button on a selected-location card clears a dropped pin or selection. The copy button copies the readable place and address.

## Start a fixed location

1. Choose the location.
2. Tap **Start Location**.
3. Follow the LocalDevVPN guidance if it appears.
4. Wait for the status to show that the location is active.

There is no separate confirmation step after choosing a location.

To move an active session, choose another place and tap **Update Location**. WrapPin keeps the existing secure session and changes the location directly.

Tap **Stop & Restore** when you want iOS to return to the real location, then confirm the choice. Keep WrapPin open while it restores the real location.

## Wi-Fi connection flow

**Settings → Tunnel App** selects LocalDevVPN (the default) or Shadowrocket. On Wi-Fi, WrapPin checks whether it can reach the paired iPhone and opens the selected app only if that connection fails. On mobile data, LocalDevVPN retains its original connect-and-return startup flow, so it still opens once; Shadowrocket is opened only after the device connection cannot be established. WrapPin cannot inspect either app's VPN switch directly.

The Shadowrocket option selects a handoff destination only. An ordinary proxy profile does not necessarily expose the local remote-pairing service. On mobile data, that device connection may fail even when Shadowrocket appears connected; switch to Wi-Fi and try again. If Wi-Fi also fails the connection check, keep LocalDevVPN as the default. Shadowrocket's profile and network combinations have not all been verified on physical devices.

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

Only LocalDevVPN startup needs this temporary change. After the secure location session is active, it can continue while mobile data is back on. Shadowrocket does not use this mobile-data-off guidance; if it cannot connect over mobile data, use Wi-Fi instead.

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

If WrapPin closes without receiving a normal end signal, the next launch explains that the previous session may still be active.

- **Resume Location** reconnects to a fixed location.
- **Resume Walking** prepares the remaining route from the most recently saved point.
- **Restore Real Location** reconnects only long enough to clear the simulated location.
- **My Real Location Is Already Back** dismisses the recovery record without reconnecting.

Nothing starts automatically from this screen.

## Appearance and accessibility

Settings offers automatic, light and dark appearance plus standard, satellite and hybrid maps. WrapPin follows iOS Dynamic Type, VoiceOver and Reduce Motion settings. At accessibility text sizes, cards and pop-ups can scroll so their controls remain reachable.

## Background sessions

An active location session uses iOS Location Services only as a background keep-alive; the coordinates still come from the native developer simulation service and are never read or stored by the keep-alive. Allow Location access when iOS asks. The blue background-location indicator may appear while a simulation is active. If access is denied, foreground simulation can still work, but continuity after switching apps is not guaranteed. **Settings → Connection Health → Background Session** shows the current keep-alive state.

## Anonymous usage statistics

The final introduction page shows **Share Anonymous Usage Statistics** before setup completes. It is off by default and sends nothing unless you choose to switch it on. The choice can be changed at any time under **Settings → Privacy**.

When enabled, WrapPin reports only a small fixed list of activity counts: the app opening or returning to the foreground, app version/build, completed onboarding or pairing, starting a fixed, walking or driving session, updating an already-active location, connection-help prompts, manual retries and successful sessions after retry, and fixed failure-stage, scheduler-reason, operation and recoverable/terminal categories (pairing, location or restoration). No raw error messages are sent. TelemetryDeck adds an approximate event time. WrapPin never includes coordinates, place names, searches, favourites, history, routes, pairing records, PINs, Apple ID, device name or diagnostics.

A random installation identifier is stored in local app storage and irreversibly hashed before sending. No per-launch session identifier is sent. Turning sharing off stops future reporting immediately and removes the local identifier, but it cannot withdraw anonymous events already received by TelemetryDeck. TelemetryDeck says it does not store IP addresses and may retain anonymous events for roughly 7–10 years without guaranteeing an exact deletion date. Counts therefore describe participating installations rather than every installation.

Open **Settings → Privacy → What Is Shared** for the same disclosure inside the app. The complete policy is in [Privacy](Privacy.md).

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

The saved pairing record belongs to a different device announcement. Toggle LocalDevVPN off and on. If the problem remains, open Device Setup, remove the pairing and pair this iPhone again.

### The real location is not visible after stopping

Keep WrapPin open for a few seconds while iOS obtains a fresh GPS result. Tap the current-location button after it becomes available. Also check that Location Services permission is allowed for WrapPin.

### A route session ended unexpectedly

Reopen WrapPin and use the interrupted-session screen. Resume from the last saved point or choose **Restore Real Location**.

### I need a readable support report

Open **Settings → Connection Health**, run the connection check, then use **Share Diagnostics**. The report contains app, iOS and connection state information but no pairing keys or PINs.
