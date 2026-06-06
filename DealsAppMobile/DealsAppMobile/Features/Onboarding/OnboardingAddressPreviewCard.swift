import SwiftUI

struct OnboardingAddressPreviewCard: View {
    let address: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Feed preview")
                .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Breeze")
                    .breezeText(.section)

                Label(address, systemImage: "mappin.and.ellipse")
                    .breezeText(.body, color: AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.large)
        .breezeSurface(
            fill: AppTheme.Colors.panelFillStrong,
            border: AppTheme.Colors.borderStrong,
            radius: AppTheme.Radii.large
        )
    }
}

#Preview {
    OnboardingAddressPreviewCard(address: "Malmö, Sodra Forstadsgatan 12")
        .padding()
        .breezeScreen()
}
