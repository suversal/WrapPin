import CoreGraphics
import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Shared viewport, sidebar, dock, and foldable-hinge layout math used across
/// standard iPhone, iPad, and iPhone Duo outer/inner displays.
enum MapLayoutMetrics {
    struct DivisionGuide: Equatable {
        var vertical: CGRect?
        var horizontal: CGRect?

        init(vertical: CGRect? = nil, horizontal: CGRect? = nil) {
            self.vertical = vertical
            self.horizontal = horizontal
        }
    }

    static func usesSidebar(for size: CGSize, division: DivisionGuide = .init()) -> Bool {
        if let rect = division.vertical,
            rect.minX >= 280,
            size.width - rect.maxX >= 280
        {
            return true
        }
        return size.width > size.height
            && (size.width >= 760 || (size.width >= 560 && size.height <= 520))
    }

    static func sidebarWidth(for size: CGSize, division: DivisionGuide = .init()) -> CGFloat {
        if let rect = division.vertical,
            rect.minX >= 280,
            size.width - rect.maxX >= 280
        {
            return min(400, rect.minX)
        }
        let maxWidth = min(400, size.width * 0.44)
        let minWidth = min(maxWidth, size.width >= 820 ? 340 : 280)
        let preferred = size.width * (size.width >= 820 ? 0.36 : 0.42)
        return min(maxWidth, max(minWidth, preferred))
    }

    static func sidebarHingeGap(
        for size: CGSize,
        sidebarWidth: CGFloat,
        division: DivisionGuide = .init()
    ) -> CGFloat {
        guard let rect = division.vertical,
            rect.width > 0,
            rect.minX >= 280,
            size.width - rect.maxX >= 280,
            sidebarWidth >= rect.minX - 1
        else {
            return 0
        }
        return rect.width
    }

    static func compactHeaderMaxHeight(availableHeight: CGFloat, isSearching: Bool) -> CGFloat {
        if isSearching {
            return max(220, availableHeight - 16)
        }
        return max(140, availableHeight * (availableHeight < 640 ? 0.40 : 0.44))
    }

    static func dockHeights(
        availableHeight: CGFloat,
        topClearance: CGFloat,
        mapControlsHeight: CGFloat,
        compactContentHeight: CGFloat,
        expandedContentHeight: CGFloat,
        warningSpace: CGFloat,
        pinsLocationHeader: Bool,
        division: DivisionGuide = .init()
    ) -> [CGFloat] {
        let maximum = max(200, availableHeight - 8)
        let clearanceLimit = availableHeight - topClearance - mapControlsHeight - 16
        let defaultMedium = availableHeight * (availableHeight < 640 ? 0.44 : 0.48)

        var mediumLimit: CGFloat
        if pinsLocationHeader {
            if clearanceLimit < defaultMedium {
                mediumLimit = max(168, clearanceLimit)
            } else {
                mediumLimit = min(availableHeight * 0.56, clearanceLimit)
            }
        } else {
            mediumLimit = min(defaultMedium, max(168, clearanceLimit))
        }

        if let hDiv = division.horizontal,
            hDiv.minY >= 160,
            availableHeight - hDiv.maxY >= 160
        {
            mediumLimit = min(mediumLimit, max(168, availableHeight - hDiv.maxY - 12))
        }

        let compactFloor: CGFloat = availableHeight < 640 ? 148 : 180
        let compactCap: CGFloat = availableHeight < 640
            ? max(compactFloor, availableHeight * 0.36)
            : maximum
        let compact = min(
            maximum,
            min(compactCap, max(compactFloor, compactContentHeight + warningSpace + 44))
        )
        let expandedContent = expandedContentHeight + warningSpace + 44
        let medium = min(maximum, max(compact, min(mediumLimit, expandedContent)))
        let full = min(maximum, max(medium + 32, expandedContent))
        return [compact, medium, full]
    }

    static func customRoutePanelHeights(
        availableHeight: CGFloat,
        isPickingOnMap: Bool,
        isAccessibilitySize: Bool,
        division: DivisionGuide = .init()
    ) -> [CGFloat] {
        let maximum = max(200, availableHeight - 84)
        let collapsedBase: CGFloat = isPickingOnMap
            ? (isAccessibilitySize ? 250 : 184)
            : (isAccessibilitySize ? 220 : 154)
        let collapsed = min(collapsedBase, maximum)
        var mediumTarget: CGFloat = isAccessibilitySize
            ? min(420, availableHeight * 0.54)
            : min(320, availableHeight * (availableHeight < 640 ? 0.44 : 0.48))
        if let hDiv = division.horizontal,
            hDiv.minY >= 160,
            availableHeight - hDiv.maxY >= 160
        {
            mediumTarget = min(mediumTarget, max(collapsed, availableHeight - hDiv.maxY - 16))
        }
        let medium = min(maximum, max(collapsed, mediumTarget))
        return [collapsed, medium, maximum]
    }

    static func modalCardMaxHeight(availableHeight: CGFloat) -> CGFloat {
        min(560, max(240, availableHeight - 28))
    }
}

#if canImport(SwiftUI)
extension MapLayoutMetrics.DivisionGuide {
    static func from(_ geometry: GeometryProxy) -> MapLayoutMetrics.DivisionGuide {
        if #available(iOS 27.1, *) {
            let regions = geometry.reservedRegions(kind: .division).filter(\.isActive)
            let vertical = regions.first { $0.frame.height > $0.frame.width && $0.frame.minX > 0 }?.frame
            let horizontal = regions.first { $0.frame.width > $0.frame.height && $0.frame.minY > 0 }?.frame
            return .init(vertical: vertical, horizontal: horizontal)
        }
        return .init()
    }
}
#endif
