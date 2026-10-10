# WrapPin Regression Checklist

Use this checklist before packaging an IPA or declaring a development build stable. Test on the physical iPhone unless a row explicitly says the simulator is sufficient.

## Install and launch

- [ ] A clean install opens the three-page introduction.
- [ ] Introduction pages swipe and advance with Continue.
- [ ] The final page clearly shows the anonymous-statistics switch before setup completes.
- [ ] A clean install initially shows sharing disabled and sends nothing before affirmative opt-in.
- [ ] An existing installation preserves its previously saved sharing choice after updating.
- [ ] Set Up This iPhone opens Device Setup instead of dropping directly onto an unexplained map.
- [ ] An update install preserves pairing, favourites, history, appearance and map style.
- [ ] Settings shows the expected version, build and plausible built date/time.

## Pairing

- [ ] Pair This iPhone starts without crashing.
- [ ] Pairing continues after switching to Settings and does not require a `BGTaskScheduler` registration.
- [ ] The six-digit PIN is readable and accepted by iOS Settings.
- [ ] Successful pairing persists after relaunch.
- [ ] Import Existing File accepts a valid pairing record.
- [ ] An invalid record produces a readable error.
- [ ] Removing pairing requires confirmation and returns the app to Not paired.

## Map and search

- [ ] Live suggestions appear after two or more characters.
- [ ] Choosing a result dismisses the keyboard and clears the search text.
- [ ] Search accepts valid latitude/longitude coordinates.
- [ ] Invalid coordinates produce a readable error without changing location.
- [ ] Tapping the map drops a pin with one non-duplicated address description.
- [ ] Clear removes the selected pin/card state.
- [ ] Done dismisses the keyboard without covering the location card.
- [ ] The compass appears only when the map is rotated, tracks heading and returns north when tapped.
- [ ] Current location returns smoothly to the real position and north-up.

## Saved places

- [ ] Adding and removing a favourite updates immediately.
- [ ] A favourite can be renamed with a trailing swipe.
- [ ] Individual favourites and history rows can be deleted with a swipe.
- [ ] Clear Favourites and Clear History each require confirmation and affect only their own list.
- [ ] Choosing a saved place closes the list and selects it on the map.
- [ ] Resume Last Location works and its dismissal remains dismissed.

## Fixed location on Wi-Fi

- [ ] With LocalDevVPN connected, Start Location becomes active without mobile-data guidance.
- [ ] After mDNS identifies the paired device, the location session connects through LocalDevVPN at `10.7.0.1` and does not use a USB/Wi-Fi-advertised `169.254.x.x` link-local address.
- [ ] With LocalDevVPN disconnected, WrapPin opens it quickly and resumes automatically.
- [ ] Selecting another place and tapping Update Location changes the active location without restarting the flow.
- [ ] The active location persists while using another app.
- [ ] The first active session requests Location access and Connection Health reports the background-session state accurately.
- [ ] With Location access denied, foreground simulation still starts and Connection Health explains that background continuity is unavailable.
- [ ] Stop & Restore requires confirmation, then restores the real location.
- [ ] The blue background-location indicator appears only while a simulation is active and disappears after Stop & Restore.

### Tunnel app handoff (new branch; physical device required)

- [ ] LocalDevVPN is the default; choosing Shadowrocket, Surge or Loon persists across launch, and reset restores the default.
- [ ] On Wi-Fi, a currently reachable paired device causes no handoff and an unreachable one opens the selected app. On mobile data, LocalDevVPN keeps its original connect-and-return flow; Shadowrocket is asked to connect its VPN through `shadowrocket://connect`, Surge is asked to start its selected configuration through `surge:///start`, and Loon is asked to turn on its VPN through `loon://on`.
- [ ] After a successful session, stopping and starting again rechecks reachability on Wi-Fi. LocalDevVPN still opens once per mobile-data startup.
- [ ] Shadowrocket, Surge or Loon on mobile data recommends switching to Wi-Fi after connection failure and never shows the LocalDevVPN mobile-data-off step; LocalDevVPN guidance remains unchanged.
- [ ] Returning after manually enabling a compatible tunnel resumes discovery; a missing or unsupported app-link scheme shows an error and the selected app's store link.
- [ ] Fixed, walking and driving sessions use the same startup path. With Shadowrocket's **Include Route 10.7.0.1/32** on, the paired-device channel is reachable and a location session starts; with it off, WrapPin must not report a connection.
- [ ] Surge iOS 5.23.0+ with the settings in [Surge iOS setup](SurgeIntegration.md) provides the paired-device channel at `10.7.0.1` and a location session starts. Without the `reflect` rule, or on an older Surge, WrapPin must not report a connection.
- [ ] Loon build 1007+ with the settings in [Loon setup](LoonIntegration.md) provides the paired-device channel at `10.7.0.1` and a location session starts. Without the `reflect` plugin, or on an older Loon, WrapPin must not report a connection.

## Fixed location on mobile data (LocalDevVPN)


- [ ] WrapPin opens LocalDevVPN when needed.
- [ ] Turn Mobile Data Off appears only for the mobile-data path.
- [ ] Turning mobile data off is detected automatically.
- [ ] Continue works as a manual fallback.
- [ ] Turn Mobile Data Back On appears only after the location session is active.
- [ ] The location remains active after 4G/5G is restored.
- [ ] An active location can be updated again without repeating startup.
- [ ] Stop restores the real location.

## Walking routes

- [ ] Preview Walking Route draws a plausible Apple Maps route.
- [ ] When a walking or driving preview has several routes, the card lists up to three; choosing one on the card or tapping it on the map highlights it and updates distance and time. Tapping away from every route still drops a pin.
- [ ] After Start, only the chosen route stays on the map and the simulated location follows it.
- [ ] Distance uses yards/miles under UK regional settings.
- [ ] Pace changes update timing before the walk starts.
- [ ] Custom walking speed supports 1–12 km/h in 0.1 km/h steps, updates timing, and can be switched back to preset paces.
- [ ] Driving speed supports 5–240 km/h in 1 km/h steps and updates timing before the route starts.
- [ ] An interrupted custom-speed walk resumes at the same speed, while older preset recovery records still restore their pace.
- [ ] Start Walking advances location along the route.
- [ ] Pause holds the current point and Resume continues from it.
- [ ] The walk continues while Apple Maps or another app is in front.
- [ ] Arrival holds the destination location.
- [ ] Walk Route Back reverses the journey.
- [ ] New Location allows a new destination without restoring the real location first.
- [ ] Stop & Restore requires confirmation and restores the real location.

## Recovery

- [ ] Force-closing during a fixed session shows interrupted-session recovery on relaunch.
- [ ] Resume Location reconnects to the saved location.
- [ ] Restore Real Location requires confirmation, clears the simulated location and leaves no new session active.
- [ ] Cancelling recovery restoration preserves the interrupted-session recovery options.
- [ ] Stop & Restore shows restoration progress for at least a moment before returning to Ready.
- [ ] Tapping the current-location button right after Stop & Restore centres the map on the real position, not on the last simulated place.
- [ ] Stopping while the session is still connecting returns to Ready promptly, without briefly applying the selected location.
- [ ] With the iPhone set to Simplified Chinese, a failed start shows a Chinese message and Connection Health reports a specific session issue stage, not `locationUnknown`.
- [ ] My Real Location Is Already Back dismisses the recovery state.
- [ ] Force-closing during a walk offers Resume Walking from a recent saved point.
- [ ] Mobile-data recovery waits until data can be restored before finishing.

## Settings, diagnostics and reset

- [ ] Automatic, Light and Dark update the Settings screen immediately.
- [ ] Standard, Satellite and Hybrid update the map.
- [ ] Connection Health reports pairing, LocalDevVPN, location-session and background-session state accurately.
- [ ] Feedback links open the correct Bug Report and Feature Request forms.
- [ ] Share Diagnostics opens the iOS share sheet and contains no keys or PINs.
- [ ] About WrapPin describes the current controls and flows.
- [ ] Replay Introduction does not delete app data.
- [ ] Privacy shows the sharing toggle and the complete What Is Shared disclosure.
- [ ] Disabling sharing takes effect immediately and remains disabled after relaunch.
- [ ] A failed first participation request is retried on the next activation.
- [ ] An app activation is counted when the app returns from the background, without a duplicate cold-launch event.
- [ ] A failed active-location update does not send an active-location-updated event.
- [ ] A build without the private TelemetryDeck configuration sends no requests.
- [ ] Usage events never contain coordinates, place names, searches, routes, pairing data or diagnostics.
- [ ] The built app contains `PrivacyInfo.xcprivacy` with tracking disabled.
- [ ] Reset WrapPin clears app data, returns to onboarding and does not alter LocalDevVPN.

## Accessibility and layout

- [ ] Normal text size retains the intended clean layout.
- [ ] Accessibility text sizes keep every primary control reachable by scrolling.
- [ ] Walking metrics and compact controls stack rather than clip at large sizes.
- [ ] VoiceOver gives meaningful names to icon-only buttons and status rows.
- [ ] Touch targets are comfortably usable.
- [ ] Reduce Motion removes nonessential map, card and onboarding animations.
- [ ] Light and dark appearances retain readable contrast.

## Final result

- [ ] No crash, hang or unexpected real-location restore occurred.
- [ ] No stale red error remained after a successful retry.
- [ ] Build succeeded in Release configuration.
- [ ] Version/build values match the planned package.
- [ ] Any known issue is recorded before distribution.
