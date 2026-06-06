import SwiftUI

struct OnboardingIntroStatCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text(title)
                .breezeText(.bodyStrong)

            Text(subtitle)
                .breezeText(.meta, color: AppTheme.Colors.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.large)
        .breezeSurface(
            fill: AppTheme.Colors.panelFill.opacity(0.86),
            border: AppTheme.Colors.border,
            radius: AppTheme.Radii.medium
        )
    }
}

#Preview {
    OnboardingIntroStatCard(
        title: "Feed",
        subtitle: "Your weekly offers, ranked around preference."
    )
    .padding()
    .breezeScreen()
}
