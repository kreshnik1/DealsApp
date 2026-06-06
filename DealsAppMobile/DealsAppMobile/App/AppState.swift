import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private let preferences: AppPreferencesStore

    var hasCompletedOnboarding: Bool
    var savedAddress: String

    init(
        preferences: AppPreferencesStore,
        hasCompletedOnboarding: Bool? = nil,
        savedAddress: String? = nil
    ) {
        let snapshot = preferences.load()
        self.preferences = preferences
        self.hasCompletedOnboarding = hasCompletedOnboarding ?? snapshot.hasCompletedOnboarding
        self.savedAddress = savedAddress ?? snapshot.savedAddress
    }

    convenience init(
        hasCompletedOnboarding: Bool? = nil,
        savedAddress: String? = nil
    ) {
        self.init(
            preferences: AppPreferencesStore(),
            hasCompletedOnboarding: hasCompletedOnboarding,
            savedAddress: savedAddress
        )
    }

    func completeOnboarding(with address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAddress.isEmpty == false else { return }

        savedAddress = trimmedAddress
        hasCompletedOnboarding = true
        persist()
    }

    func updateAddress(_ address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAddress.isEmpty == false else { return }

        savedAddress = trimmedAddress
        persist()
    }

    func replayOnboarding() {
        hasCompletedOnboarding = false
        persist()
    }

    private func persist() {
        preferences.save(
            hasCompletedOnboarding: hasCompletedOnboarding,
            savedAddress: savedAddress
        )
    }
}
