import Combine
import CoreLocation
import Foundation
import UIKit

@MainActor
final class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isFetchingCurrentLocation = false
    @Published private(set) var isResolvingTypedAddress = false
    @Published private(set) var resolvedAddress: String?
    @Published private(set) var resolvedCoordinates: UserLocationCoordinates?
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()
    private var activeResolutionID = UUID()
    private var currentLocationRequestID: UUID?

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

    var isFetching: Bool {
        isFetchingCurrentLocation || isResolvingTypedAddress
    }

    var primaryButtonTitle: String {
        if isResolved {
            return "Location Added"
        }

        if isFetchingCurrentLocation {
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
        geocoder.cancelGeocode()
        let requestID = beginResolution(kind: .currentLocation, clearsResolvedAddress: false)
        currentLocationRequestID = requestID

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finishCurrentLocationResolution(requestID: requestID)
            openAppSettings()
        @unknown default:
            finishCurrentLocationResolution(requestID: requestID)
            errorMessage = "Location unavailable right now"
        }
    }

    func prepareForManualAddressEntry() {
        invalidateActiveResolution()
        geocoder.cancelGeocode()
        resolvedAddress = nil
        resolvedCoordinates = nil
        errorMessage = nil
    }

    func resolveTypedAddress(_ address: String) async -> UserLocationCoordinates? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAddress.isEmpty == false else {
            prepareForManualAddressEntry()
            return nil
        }

        geocoder.cancelGeocode()
        let requestID = beginResolution(kind: .typedAddress, clearsResolvedAddress: true)

        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmedAddress)
            guard isActive(requestID) else { return nil }

            if let location = placemarks.first?.location?.coordinate {
                let coordinates = UserLocationCoordinates(latitude: location.latitude, longitude: location.longitude)
                resolvedCoordinates = coordinates
                errorMessage = nil
                finishTypedAddressResolution(requestID: requestID)
                return coordinates
            }

            resolvedCoordinates = nil
            errorMessage = "We couldn't verify that address"
            finishTypedAddressResolution(requestID: requestID)
            return nil
        } catch is CancellationError {
            finishTypedAddressResolution(requestID: requestID)
            return nil
        } catch {
            guard isActive(requestID) else { return nil }
            resolvedCoordinates = nil
            errorMessage = "We couldn't verify that address"
            finishTypedAddressResolution(requestID: requestID)
            return nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isFetchingCurrentLocation = false
            errorMessage = "Location access is off"
        case .notDetermined:
            break
        @unknown default:
            isFetchingCurrentLocation = false
            errorMessage = "Location unavailable right now"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isFetchingCurrentLocation = false
            errorMessage = "Could not find your location"
            return
        }

        guard let requestID = currentLocationRequestID else { return }
        Task {
            await resolveCurrentLocation(location, requestID: requestID)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isFetchingCurrentLocation = false
        currentLocationRequestID = nil
        resolvedCoordinates = nil
        resolvedAddress = nil
        errorMessage = "Try typing your address instead"
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private func beginResolution(kind: ResolutionKind, clearsResolvedAddress: Bool) -> UUID {
        let requestID = UUID()
        activeResolutionID = requestID

        switch kind {
        case .currentLocation:
            isFetchingCurrentLocation = true
            isResolvingTypedAddress = false
        case .typedAddress:
            isFetchingCurrentLocation = false
            isResolvingTypedAddress = true
        }

        if clearsResolvedAddress {
            resolvedAddress = nil
        }

        errorMessage = nil
        return requestID
    }

    private func finishCurrentLocationResolution(requestID: UUID) {
        guard isActive(requestID) else { return }
        isFetchingCurrentLocation = false
        currentLocationRequestID = nil
    }

    private func finishTypedAddressResolution(requestID: UUID) {
        guard isActive(requestID) else { return }
        isResolvingTypedAddress = false
    }

    private func invalidateActiveResolution() {
        activeResolutionID = UUID()
        currentLocationRequestID = nil
        isFetchingCurrentLocation = false
        isResolvingTypedAddress = false
    }

    private func isActive(_ requestID: UUID) -> Bool {
        activeResolutionID == requestID
    }

    private func resolveCurrentLocation(_ location: CLLocation, requestID: UUID) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard isActive(requestID) else { return }

            if let placemark = placemarks.first,
               let address = compactAddress(from: placemark) {
                resolvedCoordinates = UserLocationCoordinates(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                resolvedAddress = address
                errorMessage = nil
            } else {
                resolvedCoordinates = nil
                resolvedAddress = nil
                errorMessage = "Try typing your address instead"
            }
        } catch {
            guard isActive(requestID) else { return }
            resolvedCoordinates = nil
            resolvedAddress = nil
            errorMessage = "Try typing your address instead"
        }

        finishCurrentLocationResolution(requestID: requestID)
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

private extension OnboardingLocationManager {
    enum ResolutionKind {
        case currentLocation
        case typedAddress
    }
}
