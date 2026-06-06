import SwiftUI

struct OnboardingProgressView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? AppTheme.Colors.accent : AppTheme.Colors.borderStrong)
                    .frame(width: index == currentStep ? 28 : 10, height: 8)
                    .animation(.snappy(duration: 0.22), value: currentStep)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.top, AppTheme.Spacing.medium)
    }
}

#Preview {
    OnboardingProgressView(currentStep: 0, totalSteps: 2)
        .breezeScreen()
}
