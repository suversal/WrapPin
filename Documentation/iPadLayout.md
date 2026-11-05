# iPad layout: local Build 70 development

This change removes the orientation and layout restrictions inherited from the iPhone-only interface. No new IPA has been packaged; existing Build 69 packages are unchanged.

Build 70 also lowers the minimum OS to 18.0. Its iPad layout checks used iOS 26.3.1; iOS 18 runtime acceptance remains pending. Both editions use one package across supported OS versions.

## Previous restrictions

Both apps and the tunnel extension declared device family `1` (iPhone). The main app supported portrait only. Home placed search and session cards over a full-screen map with no wide-window layout, so its previous iPad display was not a native iPad adaptation.

## Updated behavior

- Both apps and the extension declare iPhone and iPad. iPad supports all four orientations; iPhone keeps its existing portrait setting.
- At 900 pt of available window width, search, connection status and location/route controls use a scrollable leading panel beside the map. Map centering and tap coordinates use the map's own available region.
- Narrow windows retain map overlays, capped at 560 pt. Session controls can scroll when height is constrained. The layout follows window width rather than physical device orientation or screen dimensions.
- Introduction content is capped at 640 pt, with a 600 pt footer; pairing content is capped at 640 pt and uses the system sheet.
- Rotation uses the same map, selection and session models. Pairing, location and tunnel protocols are unchanged, and there is still one app scene.

See Apple's [orientation documentation](https://developer.apple.com/documentation/uikit/uiapplication/supportedinterfaceorientations%28for%3A%29) and [iPadOS window adaptation guidance](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreen) for the platform configuration.

## Validation

Both schemes passed simulator Debug and device-target Release builds, localization and existing background/failure-stage checks. An isolated iPad mini device used the Mac's existing iOS 26.3.1 runtime; no simulator software was downloaded. The temporary device was deleted after validation.

At the standard text size, UI automation passed both landscape orientations, portrait, map selection, selection preservation after rotation, Settings and the pairing-file import entry point. Landscape used a 1133 × 744 pt window with a separate 360 pt panel and 773 × 744 pt map. Portrait used a 744 × 1133 pt map with centered overlays.

Chinese maximum accessibility text and dark mode were checked on Home and all three introduction pages; Continue and Set Up This Device remained tappable. Tool symbols are capped at 24 pt inside 44 pt hit targets, and search scope uses a separate row at accessibility sizes.

These are interface checks only. The temporary local test signature does not provide Keychain access, so real pairing/location was not verified. Physical iPad fixed location, routes, background continuity, restoration and Tunnel connections need separate acceptance. Actual split-view/window dragging, 375 pt phone screens and reduced-motion regression are also pending.
