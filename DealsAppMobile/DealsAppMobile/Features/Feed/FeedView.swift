import SwiftUI

struct FeedView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.appServices) private var appServices

    @State private var savedStores: [StoreDTO] = []
    @State private var isLoadingStores = false
    @State private var storeLoadError: String?
    @State private var warmedStoreIDs = Set<Int>()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                storesContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.large)
            .padding(.bottom, 120)
        }
        .breezeMainAppScreen()
        .navigationTitle("Home")
        .navigationSubtitle(appState.savedAddress)
        .navigationBarTitleDisplayMode(.large)
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .task(id: appState.selectedStoreIDs) {
            await loadSavedStores()
        }
        .task(id: savedStores.map(\.id)) {
            await warmSubscribedStoreOffersIfNeeded()
        }
    }

    @ViewBuilder
    private var storesContent: some View {
        if isLoadingStores && savedStores.isEmpty {
            loadingCard
        } else if let storeLoadError, savedStores.isEmpty {
            errorCard(message: storeLoadError)
        } else if savedStores.isEmpty {
            emptyCard
        } else {
            savedStoresSection
        }
    }

    private var savedStoresSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            sectionHeader("Stores You Follow")

            LazyVStack(spacing: AppTheme.Spacing.xLarge) {
                ForEach(savedStores) { store in
                    FeedStoreOfferCard(store: store, companySlug: companySlug(for: store))
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

            Text("Fetching the stores you follow.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .breezeGlassPanel(.panel, cornerRadius: AppTheme.Radii.xLarge)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Could not load your stores.")
                .breezeText(.section)

            Text(message)
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("Try Again") {
                Task {
                    await loadSavedStores(force: true)
                }
            }
            .buttonStyle(.glass)
        }
        .padding(22)
        .breezeGlassPanel(.panel, cornerRadius: AppTheme.Radii.xLarge)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("No saved stores yet.")
                .breezeText(.section)

            Text("Finish onboarding with a few stores selected and they will appear here.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .breezeGlassPanel(.panel, cornerRadius: AppTheme.Radii.xLarge)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .breezeText(.section, color: AppTheme.Colors.primaryText)
    }

    private func loadSavedStores(force: Bool = false) async {
        guard appState.selectedStoreIDs.isEmpty == false else {
            savedStores = []
            storeLoadError = nil
            warmedStoreIDs = []
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
            let allStores = try await appServices.stores.fetchStores()

            let selectedIDs = appState.selectedStoreIDs
            let selectedOrder = Dictionary(
                uniqueKeysWithValues: selectedIDs.enumerated().map { (offset: Int, id: String) in
                    (id, offset)
                }
            )

            savedStores = allStores
                .filter { selectedIDs.contains(String($0.id)) }
                .sorted { lhs, rhs in
                    let lhsIndex = selectedOrder[String(lhs.id)] ?? .max
                    let rhsIndex = selectedOrder[String(rhs.id)] ?? .max
                    return lhsIndex < rhsIndex
                }
        } catch {
            storeLoadError = error.localizedDescription
        }

        isLoadingStores = false
    }

    private func warmSubscribedStoreOffersIfNeeded() async {
        guard savedStores.isEmpty == false else { return }

        let storesToWarm = savedStores.filter { warmedStoreIDs.contains($0.id) == false }
        guard storesToWarm.isEmpty == false else { return }

        for store in storesToWarm {
            let query = StoreDealsQuery(hydrateIfEmpty: true, limit: 20, offset: 0)
            do {
                _ = try await appServices.deals.fetchStoreDeals(
                    companySlug: companySlug(for: store),
                    storeID: store.id,
                    query: query
                )
            } catch {
                // Warm in the background; keep the home screen usable even if a scrape fails.
            }

            warmedStoreIDs.insert(store.id)
        }
    }

    private func companySlug(for store: StoreDTO) -> String {
        switch store.companyID {
        case 1:
            "coop"
        case 2:
            "ica"
        case 3:
            "lidl"
        default:
            "coop"
        }
    }
}

#Preview {
    NavigationStack {
        FeedView()
            .environment(AppState(hasCompletedOnboarding: true, savedAddress: "Malmö, Sodra Forstadsgatan 12", selectedStoreIDs: ["1", "2"]))
            .environment(\.appServices, AppServices.live)
    }
}
