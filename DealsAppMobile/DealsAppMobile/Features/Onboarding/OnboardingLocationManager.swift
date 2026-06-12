import Combine
import CoreLocation
import Foundation
import UIKit

@MainActor
final class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isFetching = false
    @Published private(set) var resolvedAddress: String?
    @Published private(set) var resolvedCoordinates: UserLocationCoordinates?
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isResolved: Bool {
        resolvedAddress?.isEmpty == false
    }

    var primaryButtonTitle: String {
        if isResolved {
            return "Location Added"
        }

        if isFetching {
            return "Finding You"
        }

        switch authorizationStatus {
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Use Current Location"
        }
    }

    var primaryButtonSymbol: String {
        if isResolved {
            return "checkmark.circle.fill"
        }

        switch authorizationStatus {
        case .denied, .restricted:
            return "gearshape.fill"
        default:
            return "location.fill"
        }
    }

    func requestCurrentLocation() {
        errorMessage = nil
        isFetching = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isFetching = false
            openAppSettings()
        @unknown default:
            isFetching = false
            errorMessage = "Location unavailable right now"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isFetching = false
            errorMessage = "Location access is off"
        case .notDetermined:
            break
        @unknown default:
            isFetching = false
            errorMessage = "Location unavailable right now"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isFetching = false
            errorMessage = "Could not find your location"
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            Task { @MainActor in
                self.isFetching = false

                if let placemark = placemarks?.first,
                   let address = self.compactAddress(from: placemark) {
                    self.resolvedCoordinates = UserLocationCoordinates(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    self.resolvedAddress = address
                    self.errorMessage = nil
                } else {
                    self.resolvedCoordinates = nil
                    self.resolvedAddress = nil
                    self.errorMessage = "Try typing your address instead"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isFetching = false
        resolvedCoordinates = nil
        errorMessage = "Try typing your address instead"
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private func compactAddress(from placemark: CLPlacemark) -> String? {
        var parts = [String]()

        if let locality = placemark.locality {
            parts.append(locality)
        } else if let name = placemark.name {
            parts.append(name)
        }

        if let administrativeArea = placemark.administrativeArea, parts.contains(administrativeArea) == false {
            parts.append(administrativeArea)
        }

        if let country = placemark.country, parts.contains(country) == false {
            parts.append(country)
        }

        let address = parts.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? nil : address
    }
}
