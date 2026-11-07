import CoreLocation
import MapKit

// Keep the iOS 26 MapKit behavior while using the older equivalents on iOS 18.
@MainActor
enum MapKitCompatibility {
    static func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26, *) {
            return item.location.coordinate
        } else {
            return item.placemark.coordinate
        }
    }

    static func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
        if #available(iOS 26, *) {
            return MKMapItem(
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                address: nil
            )
        } else {
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }

    static func addressCandidates(for item: MKMapItem) -> [String?] {
        if #available(iOS 26, *) {
            return [
                item.address?.shortAddress,
                item.addressRepresentations?.cityWithContext,
                item.address?.fullAddress
            ]
        } else {
            return [
                item.placemark.title,
                item.placemark.locality,
                item.placemark.administrativeArea,
                item.placemark.country
            ]
        }
    }

    static func reverseGeocode(_ location: CLLocation) async throws -> MKMapItem? {
        if #available(iOS 26, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            request.preferredLocale = Locale.current
            return try await request.mapItems.first
        } else {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale.current
            )
            guard let placemark = placemarks.first else { return nil }
            return MKMapItem(placemark: MKPlacemark(placemark: placemark))
        }
    }
}
