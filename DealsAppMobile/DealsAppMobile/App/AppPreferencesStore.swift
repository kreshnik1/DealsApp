import Foundation

struct AppPreferencesSnapshot {
    var hasCompletedOnboarding: Bool
    var savedAddress: String
}

struct AppPreferencesStore {
    private enum Keys {
        static let hasCompletedOnboarding = "app.hasCompletedOnboarding"
        static let savedAddress = "app.savedAddress"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferencesSnapshot {
        AppPreferencesSnapshot(
            hasCompletedOnboarding: defaults.bool(forKey: Keys.hasCompletedOnboarding),
            savedAddress: defaults.string(forKey: Keys.savedAddress) ?? ""
        )
    }

    func save(hasCompletedOnboarding: Bool, savedAddress: String) {
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        defaults.set(savedAddress, forKey: Keys.savedAddress)
    }
}
