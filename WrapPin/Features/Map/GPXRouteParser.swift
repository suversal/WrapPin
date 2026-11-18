import CoreLocation
import Foundation

struct GPXRouteSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
}

enum GPXRouteError: LocalizedError {
    case invalidFile, invalidPoints, tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFile: String(localized: "Choose a valid GPX file containing a track segment or route with at least two points.")
        case .invalidPoints: String(localized: "A route needs at least two different points with valid latitude and longitude.")
        case .tooLarge: String(localized: "Use a GPX file smaller than 5 MB with at most 10,000 points.")
        }
    }
}

/// No network requests, external entities, elevation or recorded timestamps.
final class GPXRouteParser: NSObject, XMLParserDelegate {
    static let maximumPointCount = 10_000
    static let maximumFileSize = 5 * 1_024 * 1_024
    private var segments: [GPXRouteSegment] = []
    private var current: [CLLocationCoordinate2D]?
    private var container: String?
    private var path: [String] = []
    private var pointCount = 0
    private var failure: GPXRouteError?

    static func parse(_ data: Data) throws -> [GPXRouteSegment] {
        guard data.count <= maximumFileSize else { throw GPXRouteError.tooLarge }
        let delegate = GPXRouteParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let succeeded = parser.parse()
        if let failure = delegate.failure { throw failure }
        guard succeeded, !delegate.segments.isEmpty else { throw GPXRouteError.invalidFile }
        return delegate.segments
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        let parent = path.last
        path.append(elementName)
        if path.count == 1, elementName != "gpx" { reject(parser, .invalidFile); return }
        if (elementName == "trkseg" && parent == "trk") || (elementName == "rte" && parent == "gpx") {
            guard current == nil else { reject(parser, .invalidFile); return }
            current = []
            container = elementName
        }
        guard (elementName == "trkpt" && parent == "trkseg") || (elementName == "rtept" && parent == "rte") else { return }
        guard current != nil,
              let latitude = attributes["lat"].flatMap(Double.init),
              let longitude = attributes["lon"].flatMap(Double.init),
              CLLocationCoordinate2DIsValid(.init(latitude: latitude, longitude: longitude)) else {
            reject(parser, .invalidPoints); return
        }
        pointCount += 1
        guard pointCount <= Self.maximumPointCount else { reject(parser, .tooLarge); return }
        current?.append(.init(latitude: latitude, longitude: longitude))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == container, let coordinates = current {
            if coordinates.count >= 2 {
                segments.append(GPXRouteSegment(id: segments.count, coordinates: coordinates))
            }
            current = nil
            container = nil
        }
        _ = path.popLast()
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        reject(parser, .invalidFile)
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        reject(parser, .invalidFile)
    }

    private func reject(_ parser: XMLParser, _ error: GPXRouteError) {
        failure = error
        parser.abortParsing()
    }
}
