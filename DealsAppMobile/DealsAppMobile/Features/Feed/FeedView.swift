import SwiftUI

struct FeedView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.appServices) private var appServices

    @State private var savedStores: [StoreDTO] = []
    @State private var isLoadingStores = false
    @State private var storeLoadError: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                savedStoresSection
//                supportingNote
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.xLarge)
            .padding(.bottom, AppTheme.Spacing.xxLarge)
        }
        .background(Color(uiColor: .systemBackground))
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
                        .font(.system(size: AppTheme.IconSizes.toolbar, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
            }
        }
        .task(id: appState.selectedStoreIDs) {
            await loadSavedStores()
        }
    }

    @ViewBuilder
    private var savedStoresSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            sectionHeader("Your Stores")

            if isLoadingStores && savedStores.isEmpty {
                loadingCard
            } else if let storeLoadError, savedStores.isEmpty {
                errorCard(message: storeLoadError)
            } else if savedStores.isEmpty {
                emptyCard
            } else {
                LazyVStack(spacing: AppTheme.Spacing.xLarge) {
                    ForEach(savedStores) { store in
                        FeedStoreOfferCard(store: store, companySlug: "coop")
                    }
                }
            }
        }
    }

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Loading your stores")
                .breezeText(.section)

            ProgressView()
                .tint(AppTheme.Colors.accent)

            Text("Fetching the saved Coop sample so the feed can render live store cards.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(sectionPanel)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Could not load your saved stores.")
                .breezeText(.section)

            Text(message)
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("Try Again") {
                Task {
                    await loadSavedStores(force: true)
                }
            }
            .buttonStyle(AppButtonStyle(variant: .secondary, fillsWidth: false))
        }
        .padding(22)
        .background(sectionPanel)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("No saved stores yet.")
                .breezeText(.section)

            Text("Finish onboarding with a few Coop stores selected and they will appear here as full feed cards.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(sectionPanel)
    }

    private var supportingNote: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            sectionHeader("What Comes Next")

            Text("This is the first store-focused feed module. Next we can tune the card composition, swap in real deal counts, or thread weekly offers directly into each store block.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }

    private var sectionPanel: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous)
            .fill(AppTheme.Colors.panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous)
                    .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Text(title)
                .breezeText(.section, color: AppTheme.Colors.primaryText)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText.opacity(0.78))

            Spacer(minLength: 0)
        }
    }

    private func loadSavedStores(force: Bool = false) async {
        guard appState.selectedStoreIDs.isEmpty == false else {
            savedStores = []
            storeLoadError = nil
            return
        }

        guard force || savedStores.isEmpty else {
            return
        }

        guard isLoadingStores == false else {
            return
        }

        isLoadingStores = true
        storeLoadError = nil

        do {
            let allStores = try await appServices.stores.fetchCompanyStores(
                companySlug: "coop",
                query: CompanyStoresQuery(limit: 10)
            )

            let selectedIDs = appState.selectedStoreIDs
            savedStores = allStores.filter { selectedIDs.contains(String($0.id)) }
        } catch {
            storeLoadError = error.localizedDescription
        }

        isLoadingStores = false
    }
}

#Preview {
    NavigationStack {
        FeedView()
            .environment(AppState(hasCompletedOnboarding: true, savedAddress: "Malmö, Sodra Forstadsgatan 12", selectedStoreIDs: ["1", "2"]))
            .environment(\.appServices, AppServices.live)
    }
}
