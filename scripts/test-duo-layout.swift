import CoreGraphics
import Foundation

private func assertTrue(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct TestDuoLayout {
    static func main() {
        // 1. Standard iPhone portrait (SE / 16 Pro) and Duo outer portrait
        assertTrue(!MapLayoutMetrics.usesSidebar(for: CGSize(width: 375, height: 667)), "iPhone SE portrait should use compact mode")
        assertTrue(!MapLayoutMetrics.usesSidebar(for: CGSize(width: 402, height: 781)), "iPhone 16 Pro portrait should use compact mode")
        assertTrue(!MapLayoutMetrics.usesSidebar(for: CGSize(width: 466, height: 585)), "iPhone Duo outer portrait should use compact mode")

        // 2. iPhone Duo inner portrait (669x890 safe) should use vertical layout (not sidebar)
        assertTrue(!MapLayoutMetrics.usesSidebar(for: CGSize(width: 669, height: 890)), "iPhone Duo inner portrait should use compact controls")

        // 3. iPhone Duo inner landscape (both raw 951x625 and inset 892x625) should use sidebar
        assertTrue(MapLayoutMetrics.usesSidebar(for: CGSize(width: 951, height: 625)), "iPhone Duo inner landscape 951x625 should use sidebar")
        assertTrue(MapLayoutMetrics.usesSidebar(for: CGSize(width: 892, height: 625)), "iPhone Duo inner landscape 892x625 should use sidebar")

        // 4. Compact landscape (Duo outer landscape 600x445, iPhone landscape 756x381) should use sidebar
        assertTrue(MapLayoutMetrics.usesSidebar(for: CGSize(width: 600, height: 445)), "iPhone Duo outer landscape should use sidebar")
        assertTrue(MapLayoutMetrics.usesSidebar(for: CGSize(width: 756, height: 381)), "iPhone 16 Pro landscape should use sidebar")

        // 5. iPad portrait vs landscape
        assertTrue(!MapLayoutMetrics.usesSidebar(for: CGSize(width: 744, height: 1090)), "iPad mini portrait should not use sidebar")
        assertTrue(MapLayoutMetrics.usesSidebar(for: CGSize(width: 1133, height: 700)), "iPad mini landscape should use sidebar")
        assertTrue(MapLayoutMetrics.usesSidebar(for: CGSize(width: 1366, height: 980)), "iPad 13 landscape should use sidebar")

        // 6. Book posture with active vertical division
        let bookSize = CGSize(width: 951, height: 625)
        let verticalDivision = MapLayoutMetrics.DivisionGuide(
            vertical: CGRect(x: 470, y: 0, width: 11, height: 625)
        )
        assertTrue(MapLayoutMetrics.usesSidebar(for: bookSize, division: verticalDivision), "Book posture should use sidebar")
        let bookSidebar = MapLayoutMetrics.sidebarWidth(for: bookSize, division: verticalDivision)
        assertTrue(bookSidebar <= 470, "Sidebar width (\(bookSidebar)) must not cross vertical hinge at x=470")
        let gap = MapLayoutMetrics.sidebarHingeGap(for: bookSize, sidebarWidth: bookSidebar, division: verticalDivision)
        assertTrue(gap == 0 || gap == 11, "Sidebar hinge gap must match division or be 0 when narrower")

        let narrowBookSize = CGSize(width: 720, height: 640)
        let narrowDivision = MapLayoutMetrics.DivisionGuide(
            vertical: CGRect(x: 355, y: 0, width: 10, height: 640)
        )
        assertTrue(MapLayoutMetrics.usesSidebar(for: narrowBookSize, division: narrowDivision), "Split vertical division >=280 per side should use sidebar")
        let narrowSidebar = MapLayoutMetrics.sidebarWidth(for: narrowBookSize, division: narrowDivision)
        assertTrue(narrowSidebar == 355, "Sidebar should snap to 355 before vertical division")
        let narrowGap = MapLayoutMetrics.sidebarHingeGap(for: narrowBookSize, sidebarWidth: narrowSidebar, division: narrowDivision)
        assertTrue(narrowGap == 10, "Hinge gap should equal division width 10 when sidebar stops at hinge")

        // 7. Short screen (Duo outer portrait 466x585) collision avoidance
        let outerHeight: CGFloat = 585
        let headerClearance: CGFloat = 190
        let controlsHeight: CGFloat = 152
        let dockHeights = MapLayoutMetrics.dockHeights(
            availableHeight: outerHeight,
            topClearance: headerClearance,
            mapControlsHeight: controlsHeight,
            compactContentHeight: 110,
            expandedContentHeight: 340,
            warningSpace: 0,
            pinsLocationHeader: true
        )
        assertTrue(dockHeights.count == 3, "Dock heights must return 3 detents")
        assertTrue(dockHeights[0] <= dockHeights[1] && dockHeights[1] <= dockHeights[2], "Detents must be monotonic")
        assertTrue(
            headerClearance + controlsHeight + dockHeights[1] <= outerHeight,
            "Medium dock (\(dockHeights[1])) + controls (\(controlsHeight)) + topClearance (\(headerClearance)) must fit in \(outerHeight)"
        )

        // 8. Tabletop posture (horizontal division on inner portrait 669x890)
        let innerPortraitHeight: CGFloat = 890
        let tabletopDivision = MapLayoutMetrics.DivisionGuide(
            horizontal: CGRect(x: 0, y: 440, width: 669, height: 10)
        )
        let tabletopDock = MapLayoutMetrics.dockHeights(
            availableHeight: innerPortraitHeight,
            topClearance: 180,
            mapControlsHeight: 152,
            compactContentHeight: 120,
            expandedContentHeight: 520,
            warningSpace: 0,
            pinsLocationHeader: true,
            division: tabletopDivision
        )
        assertTrue(
            tabletopDock[1] <= innerPortraitHeight - 450,
            "Tabletop medium dock (\(tabletopDock[1])) must stay below horizontal hinge"
        )

        // 9. Custom route panel heights on Duo outer display and tabletop
        let customOuter = MapLayoutMetrics.customRoutePanelHeights(
            availableHeight: 585,
            isPickingOnMap: false,
            isAccessibilitySize: false
        )
        assertTrue(customOuter[0] < customOuter[1] && customOuter[1] < customOuter[2], "Custom route detents must increase strictly")
        assertTrue(customOuter[1] <= 260, "Custom route medium panel on 585pt screen should stay <= 260pt (got \(customOuter[1]))")

        let customTabletop = MapLayoutMetrics.customRoutePanelHeights(
            availableHeight: 890,
            isPickingOnMap: false,
            isAccessibilitySize: false,
            division: tabletopDivision
        )
        assertTrue(customTabletop[1] <= 440, "Custom route medium panel must stay below horizontal hinge")

        // 10. Modal max height bounds
        assertTrue(MapLayoutMetrics.modalCardMaxHeight(availableHeight: 400) == 372, "Modal max height on short landscape should clamp to height - 28")
        assertTrue(MapLayoutMetrics.modalCardMaxHeight(availableHeight: 800) == 560, "Modal max height on tall screen should cap at 560")

        print("iPhone Duo layout metrics checks passed.")
    }
}
