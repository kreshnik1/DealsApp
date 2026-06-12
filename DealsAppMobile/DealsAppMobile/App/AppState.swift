import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private let preferences: AppPreferencesStore

    var hasCompletedOnboarding: Bool
    var savedAddress: String
    var selectedStoreIDs: Set<String>
    var locationCoordinates: UserLocationCoordinates?
    var weeklyGroceryBudget: WeeklyGroceryBudget?

    init(
        preferences: AppPreferencesStore,
        hasCompletedOnboarding: Bool? = nil,
        savedAddress: String? = nil,
        selectedStoreIDs: Set<String>? = nil,
        locationCoordinates: UserLocationCoordinates? = nil,
        weeklyGroceryBudget: WeeklyGroceryBudget? = nil
    ) {
        let snapshot = preferences.load()
        self.preferences = preferences
        self.hasCompletedOnboarding = hasCompletedOnboarding ?? snapshot.hasCompletedOnboarding
        self.savedAddress = savedAddress ?? snapshot.savedAddress
        self.selectedStoreIDs = selectedStoreIDs ?? Set(snapshot.selectedStoreIDs)
        self.locationCoordinates = locationCoordinates ?? snapshot.locationCoordinates
        self.weeklyGroceryBudget = weeklyGroceryBudget ?? snapshot.weeklyGroceryBudget
    }

    convenience init(
        hasCompletedOnboarding: Bool? = nil,
        savedAddress: String? = nil,
        selectedStoreIDs: Set<String>? = nil,
        locationCoordinates: UserLocationCoordinates? = nil,
        weeklyGroceryBudget: WeeklyGroceryBudget? = nil
    ) {
        self.init(
            preferences: AppPreferencesStore(),
            hasCompletedOnboarding: hasCompletedOnboarding,
            savedAddress: savedAddress,
            selectedStoreIDs: selectedStoreIDs,
            locationCoordinates: locationCoordinates,
            weeklyGroceryBudget: weeklyGroceryBudget
        )
    }

    func completeOnboarding(
        with address: String,
        selectedStoreIDs: Set<String>,
        locationCoordinates: UserLocationCoordinates?,
        weeklyGroceryBudget: WeeklyGroceryBudget?
    ) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAddress.isEmpty == false else { return }

        savedAddress = trimmedAddress
        self.selectedStoreIDs = selectedStoreIDs
        self.locationCoordinates = locationCoordinates
        self.weeklyGroceryBudget = weeklyGroceryBudget
        hasCompletedOnboarding = true
        persist()
    }

    func updateAddress(_ address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAddress.isEmpty == false else { return }

        savedAddress = trimmedAddress
        locationCoordinates = nil
        persist()
    }

    func replayOnboarding() {
        hasCompletedOnboarding = false
        persist()
    }

    private func persist() {
        preferences.save(
            hasCompletedOnboarding: hasCompletedOnboarding,
            savedAddress: savedAddress,
            selectedStoreIDs: selectedStoreIDs.sorted(),
            locationCoordinates: locationCoordinates,
            weeklyGroceryBudget: weeklyGroceryBudget
        )
    }
}
