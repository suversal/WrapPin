# WrapPin 1.0.24 (Build 88)

[简体中文](Release-1.0.24.zh-CN.md)

Custom routes let you simulate movement where Apple Maps walking directions are unavailable.

- Search for stops, paste coordinates, or tap the map to choose a start, destination and intermediate waypoints. Reorder with the drag handle, remove individual stops, confirm clear-all, or undo changes.
- Import GPX tracks or routes, with segment selection. Limits: 5 MB and 10,000 points.
- Set one simulation speed from 0.1–240 km/h in 0.1 km/h steps. Start, pause, resume, follow the route back, or stop and restore the real location.
- Custom stops connect with straight lines in order, without Apple walking directions or automatic road snapping. Add waypoints or import a suitable GPX to follow roads.
- Route geometry, GPX parsing and recovery records stay on the device. Complete custom routes are not uploaded for planning. Map display and place searches may still need internet access through the existing providers.
- Home and route drawers support compact, half and expanded positions, with improved readability, button bounds and compact summaries. The empty home screen uses a small search prompt.
- Removes spring drawer snapping and adds current-location centering to the route editor, using trusted location or the home map viewport on first entry.

## Installation

Both downloads are unsigned IPAs for iOS/iPadOS 18.0+. Choose Standard for SideStore and an external device tunnel. Tunnel includes a device tunnel and requires matching Packet Tunnel signing entitlements. Upgrade the same edition with the existing signing identity; working pairing records do not need to be removed.

## Validation

Local checks cover geometry, GPX, speed, movement, pause, reconnect, stop, arrival, return, stop selection and recovery. Location continuity, localization, both Release archives and package integrity are rechecked. Earlier iOS 26 Simulator UI checks cover repeated drawer drags, the unified speed interface and cached-location centering. UI checks use synthetic state and public coordinates without a real-device transport. iOS 18 interaction, signed installation of this release and extended background operation remain to be verified on a physical device.
