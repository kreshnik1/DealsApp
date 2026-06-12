import Foundation

struct AppPreferencesSnapshot {
    var hasCompletedOnboarding: Bool
    var savedAddress: String
    var selectedStoreIDs: [String]
    var locationCoordinates: UserLocationCoordinates?
    var weeklyGroceryBudget: WeeklyGroceryBudget?
}

struct AppPreferencesStore {
    private enum Keys {
        static let hasCompletedOnboarding = "app.hasCompletedOnboarding"
        static let savedAddress = "app.savedAddress"
        static let selectedStoreIDs = "app.selectedStoreIDs"
        static let latitude = "app.location.latitude"
        static let longitude = "app.location.longitude"
        static let weeklyGroceryBudget = "app.weeklyGroceryBudget"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferencesSnapshot {
        let latitude = defaults.object(forKey: Keys.latitude) as? Double
        let longitude = defaults.object(forKey: Keys.longitude) as? Double

        return AppPreferencesSnapshot(
            hasCompletedOnboarding: defaults.bool(forKey: Keys.hasCompletedOnboarding),
            savedAddress: defaults.string(forKey: Keys.savedAddress) ?? "",
            selectedStoreIDs: defaults.stringArray(forKey: Keys.selectedStoreIDs) ?? [],
            locationCoordinates: coordinates(latitude: latitude, longitude: longitude),
            weeklyGroceryBudget: defaults.string(forKey: Keys.weeklyGroceryBudget)
                .flatMap(WeeklyGroceryBudget.init(rawValue:))
        )
    }

    func save(
        hasCompletedOnboarding: Bool,
        savedAddress: String,
        selectedStoreIDs: [String],
        locationCoordinates: UserLocationCoordinates?,
        weeklyGroceryBudget: WeeklyGroceryBudget?
    ) {
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        defaults.set(savedAddress, forKey: Keys.savedAddress)
        defaults.set(selectedStoreIDs, forKey: Keys.selectedStoreIDs)
        defaults.set(locationCoordinates?.latitude, forKey: Keys.latitude)
        defaults.set(locationCoordinates?.longitude, forKey: Keys.longitude)
        defaults.set(weeklyGroceryBudget?.rawValue, forKey: Keys.weeklyGroceryBudget)
    }

    private func coordinates(latitude: Double?, longitude: Double?) -> UserLocationCoordinates? {
        guard let latitude, let longitude else {
            return nil
        }

        return UserLocationCoordinates(latitude: latitude, longitude: longitude)
    }
}
