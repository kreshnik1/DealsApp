import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep = 0

    var body: some View {
        TabView(selection: $currentStep) {
            OnboardingIntroView(onContinue: showAddressStep)
                .tag(0)

            OnboardingAddressView(onBack: showIntroStep)
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .breezeScreen()
        .safeAreaInset(edge: .top) {
            OnboardingProgressView(currentStep: currentStep, totalSteps: 2)
        }
    }

    private func showAddressStep() {
        withAnimation(.snappy(duration: 0.32, extraBounce: 0)) {
            currentStep = 1
        }
    }

    private func showIntroStep() {
        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
            currentStep = 0
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environment(AppState(hasCompletedOnboarding: false, savedAddress: ""))
}
