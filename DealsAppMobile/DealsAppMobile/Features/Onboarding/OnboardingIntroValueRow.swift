import SwiftUI

struct OnboardingIntroValueRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 40, height: 40)
                .breezeSurface(
                    fill: AppTheme.Colors.panelFillStrong,
                    border: AppTheme.Colors.borderStrong,
                    radius: AppTheme.Radii.medium
                )

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xSmall) {
                Text(title)
                    .breezeText(.bodyStrong)

                Text(message)
                    .breezeText(.body, color: AppTheme.Colors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingIntroValueRow(
        icon: "sparkles",
        title: "Personal first",
        message: "The feed will be shaped around the stores you actually visit."
    )
    .padding()
    .breezeScreen()
}
