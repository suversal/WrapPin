# iPad map controls: Build 71

The minimum OS remains iOS/iPadOS 18.0. Both editions share this layout; pairing and location engines are unchanged. Build 70 packages and records are preserved. Build 71 packaging is pending.

## Interaction

- **Wide landscape windows:** at least 900 pt wide and wider than tall, use the leading panel. Hide Controls or a left swipe on its header hides it. Show Controls at the top leading corner restores it.
- **Hidden sidebar:** an existing place/route retains a compact bottom card. Fixed location keeps status and Stop & Restore; routes keep Pause/Resume and Stop. Show Details restores the sidebar and expands details without clearing selection or stopping a session.
- **Portrait/narrow windows:** search and shortcuts stay at the top; session cards dock above the bottom safe area with a 420 pt content cap. Short cards fit their content and long ones scroll. Header and dock reserve space for each other.
- **Disclosure:** both fixed/route cards have a visible button and header-only vertical drag. The card body does not intercept scrolling, coordinate selection or speed controls.
- **Preferences:** iPad defaults to compact presentation on first use of the new layout. Legacy iPhone collapse preferences are retained. Fixed/route disclosure survives rotation; sidebar visibility is stored separately.
- **Messages:** map messages clear the current dock and sidebar rather than relying on a fixed offset.

Hiding controls changes presentation only. It does not stop simulation, clear the selected point or re-pair. Stopping uses the existing confirmation/restoration flow.

## Validation and limits

At standard text size, iPad mini UI checks passed portrait bottom docking, both landscape orientations, sidebar hide/restore, selection preservation, fixed/route disclosure and Stop confirmation access. The fixed/route checks also passed on a 375 pt iPhone. Maximum accessibility text and dark-mode checks also passed on both devices, rendering the reduced-motion branch. At large text sizes, the bounded card may need scrolling to reach its controls.

UI tests use synthetic active-location/route states in a temporary project, without connecting to a real location service. Test data, widened setters and state injection are absent from production source. The production project retains the minimum-iOS-18 build check.

On 7 November 2026 the user reported working location and landscape on iPad iOS 26, providing the layout screenshots addressed here. The exact build, edition and full acceptance matrix were not separately confirmed. Build 71 device location, routes, background/restoration, iOS 18 runtime and actual window dragging/split-view resizing remain pending.
