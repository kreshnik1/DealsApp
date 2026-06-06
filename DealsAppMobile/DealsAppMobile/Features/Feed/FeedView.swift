import SwiftUI

struct FeedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xLarge) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("The foundation is ready.")
                        .font(AppTheme.Typography.cardTitle)

                    Text("This first pass keeps the Feed intentionally quiet. The title, subtitle, shell, and theme system are in place so the weekly store cards can be added on top without reworking the structure.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .padding(AppTheme.Spacing.large)
                .breezeGlassPanel(.feature, cornerRadius: AppTheme.Radii.large)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text("Next layer")
                        .font(AppTheme.Typography.eyebrow)
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    Text("This week and Most saved will slot into this Feed rhythm next, using store imagery, logos, and real offer data.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .padding(.horizontal, AppTheme.Spacing.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.xLarge)
            .padding(.bottom, AppTheme.Spacing.xxLarge)
        }
        .breezeScreen()
        .navigationTitle("Breeze")
        .navigationSubtitle(appState.savedAddress)
        .navigationBarTitleDisplayMode(.large)
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedView()
            .environment(AppState(hasCompletedOnboarding: true, savedAddress: "Malmö, Sodra Forstadsgatan 12"))
    }
}
