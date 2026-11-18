# WrapPin 1.0.25 (Build 93)

[简体中文](Release-1.0.25.zh-CN.md)

- Domestic route-place input and Search now use the same autocomplete candidates. Search dismisses the keyboard and retains the list instead of replacing it with keyword-search results. The provider determines the number of candidates, up to six.
- Tap a specific suggestion to add it directly and return to the route. Suggestions show the same add icon as search results.
- Resolve the selected completion itself; ignore cancelled or stale replies and prevent duplicate selection.
- Coordinate input, overseas search and the main map search keep their existing behavior.

Unsigned IPAs for iOS/iPadOS 18.0+. Choose Standard for SideStore; Tunnel requires matching Packet Tunnel signing entitlements. Upgrade the same edition with the existing signing identity.

Validation covers candidate retention, selection, coordinates, failures, cancellation, stale replies, recovery and location continuity, plus both Release archives and IPA integrity. Simulator UI checks use injected candidates and a local resolver; actual provider output and signed device installation remain to be verified on a phone.
