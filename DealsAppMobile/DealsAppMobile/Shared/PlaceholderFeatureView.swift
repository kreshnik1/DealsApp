import SwiftUI

struct PlaceholderFeatureView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.accent)

                    Text(message)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    Text("This area is part of the first shell only.")
                        .font(AppTheme.Typography.bodyEmphasis)

                    Text("The app structure is in place so we can style and build each feature incrementally without reworking the foundation.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .padding(AppTheme.Spacing.large)
                .breezeGlassPanel(.panel, cornerRadius: AppTheme.Radii.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.xLarge)
            .padding(.bottom, AppTheme.Spacing.xxLarge)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        PlaceholderFeatureView(
            title: "Stores",
            systemImage: "building.2.fill",
            message: "Nearby store browsing will come next."
        )
    }
}
