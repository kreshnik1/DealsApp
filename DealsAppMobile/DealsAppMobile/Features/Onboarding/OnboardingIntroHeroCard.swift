import SwiftUI

struct OnboardingIntroHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            Label("A quieter way in", systemImage: "leaf.fill")
                .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Build your feed around the stores that matter to you.")
                    .breezeText(.title)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Start with a simple location, move into your favorite stores, and let the feed do the sorting.")
                    .breezeText(.body, color: AppTheme.Colors.secondaryText)
                    .lineSpacing(4)
            }

            HStack(spacing: AppTheme.Spacing.medium) {
                OnboardingIntroStatCard(
                    title: "Feed",
                    subtitle: "Your weekly offers, ranked around preference."
                )

                OnboardingIntroStatCard(
                    title: "Stores",
                    subtitle: "Nearby context and favorites from day one."
                )
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.heroStart,
                    AppTheme.Colors.heroEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .breezeSurface(
            fill: .clear,
            border: AppTheme.Colors.borderStrong,
            radius: AppTheme.Radii.xLarge
        )
        .shadow(
            color: AppTheme.Shadows.ambient.color,
            radius: AppTheme.Shadows.ambient.radius,
            x: AppTheme.Shadows.ambient.x,
            y: AppTheme.Shadows.ambient.y
        )
    }
}

#Preview {
    OnboardingIntroHeroCard()
        .padding()
        .breezeScreen()
}
