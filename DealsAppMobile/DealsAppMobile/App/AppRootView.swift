import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.snappy(duration: 0.45, extraBounce: 0.02), value: appState.hasCompletedOnboarding)
    }
}

#Preview("Onboarding") {
    AppRootView()
        .environment(AppState(hasCompletedOnboarding: false, savedAddress: "", selectedStoreIDs: []))
}

#Preview("Main App") {
    AppRootView()
        .environment(AppState(hasCompletedOnboarding: true, savedAddress: "Malmö Centralstation", selectedStoreIDs: ["1", "2", "3"]))
}
