import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var selectedAddress = ""
    @State private var selectedShopIDs: Set<String> = []
    @State private var selectedLocationCoordinates: UserLocationCoordinates?
    @State private var selectedWeeklyBudget: WeeklyGroceryBudget?

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            TabView(selection: $currentStep) {
                OnboardingIntroView(isActive: currentStep == 0)
                    .tag(0)

                OnboardingAddressView(
                    isActive: currentStep == 1,
                    address: $selectedAddress,
                    locationCoordinates: $selectedLocationCoordinates
                )
                    .tag(1)

                OnboardingSubscriptionsView(
                    isActive: currentStep == 2,
                    address: selectedAddress,
                    selectedShopIDs: $selectedShopIDs
                )
                .tag(2)

                OnboardingBudgetView(
                    isActive: currentStep == 3,
                    selectedBudget: $selectedWeeklyBudget
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .top) {
            OnboardingProgressView(currentStep: currentStep, totalSteps: 4)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingBottomActionBar(
                title: currentStep == 3 ? "Finish" : "Next",
                isDisabled: isPrimaryActionDisabled,
                action: advance
            )
        }
        .onAppear {
            if selectedAddress.isEmpty {
                selectedAddress = appState.savedAddress
            }
            if selectedShopIDs.isEmpty {
                selectedShopIDs = appState.selectedStoreIDs
            }
            if selectedLocationCoordinates == nil {
                selectedLocationCoordinates = appState.locationCoordinates
            }
            if selectedWeeklyBudget == nil {
                selectedWeeklyBudget = appState.weeklyGroceryBudget
            }
        }
    }

    private var isPrimaryActionDisabled: Bool {
        switch currentStep {
        case 1:
            selectedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            selectedWeeklyBudget == nil
        default:
            false
        }
    }

    private func advance() {
        guard isPrimaryActionDisabled == false else { return }

        if currentStep == 3 {
            appState.completeOnboarding(
                with: selectedAddress,
                selectedStoreIDs: selectedShopIDs,
                locationCoordinates: selectedLocationCoordinates,
                weeklyGroceryBudget: selectedWeeklyBudget
            )
            return
        }

        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
            currentStep += 1
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environment(AppState(hasCompletedOnboarding: false, savedAddress: "", selectedStoreIDs: []))
}
