import SwiftUI

struct OnboardingIntroView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                Spacer(minLength: AppTheme.Spacing.large)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text(AppTheme.brandEyebrow)
                        .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

                    Text("Weekly grocery offers, without the supermarket chaos.")
                        .breezeText(.hero)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Breeze starts with the stores you care about and turns their weekly offers into a calmer, more personal feed.")
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OnboardingIntroHeroCard()

                VStack(spacing: AppTheme.Spacing.large) {
                    OnboardingIntroValueRow(
                        icon: "sparkles",
                        title: "Personal first",
                        message: "The feed will be shaped around the stores you actually visit."
                    )

                    OnboardingIntroValueRow(
                        icon: "mappin.and.ellipse",
                        title: "Location-aware",
                        message: "Your address becomes the starting point for nearby stores and local weekly deals."
                    )
                }

                Spacer(minLength: AppTheme.Spacing.xxLarge)
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.xxLarge)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            OnboardingBottomActionBar(
                title: "Continue",
                action: onContinue
            )
        }
    }
}
