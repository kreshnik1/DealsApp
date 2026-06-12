import SwiftUI

struct OnboardingSubscriptionsView: View {
    @Environment(\.appServices) private var appServices

    let isActive: Bool
    let address: String
    @State private var showsText = false
    @State private var revealSequence = 0
    @State private var shopOptions: [OnboardingShopOption] = []
    @State private var hasLoadedStores = false
    @State private var isLoadingStores = false
    @State private var storeLoadError: String?
    @Binding var selectedShopIDs: Set<String>

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.xxLarge) {
                Spacer(minLength: 72)

                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("Subscribe to get the latest offers")
                        .font(.system(size: 44, weight: .bold))
                        .tracking(-1.4)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .opacity(showsText ? 1 : 0)
                .blur(radius: showsText ? 0 : 10)
                .offset(y: showsText ? 0 : 24)

                content
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 140)
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.xxLarge)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            runRevealSequence()
        }
        .onChange(of: isActive, initial: false) { _, _ in
            runRevealSequence()
        }
        .task(id: isActive) {
            guard isActive else { return }
            await loadCoopStoresIfNeeded()
        }
    }

    private var subtitle: String {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAddress.isEmpty {
            return "Choose a few stores to start."
        }

        return "Stores near \(trimmedAddress)"
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingStores && shopOptions.isEmpty {
            ProgressView("Loading Coop stores...")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .padding(.vertical, AppTheme.Spacing.xxLarge)
        } else if let storeLoadError, shopOptions.isEmpty {
            VStack(spacing: AppTheme.Spacing.medium) {
                Text("Could not load Coop stores.")
                    .breezeText(.bodyStrong)

                Text(storeLoadError)
                    .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task {
                        await loadCoopStores(force: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.xxLarge)
            .background(selectionCard(isSelected: false))
        } else if shopOptions.isEmpty {
            Text("No Coop stores with details are available yet.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .padding(.vertical, AppTheme.Spacing.xxLarge)
        } else {
            LazyVStack(spacing: AppTheme.Spacing.medium) {
                ForEach(shopOptions) { shop in
                    Button {
                        toggle(shop.id)
                    } label: {
                        HStack(spacing: AppTheme.Spacing.large) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                                Text(shop.name)
                                    .breezeText(.bodyStrong)

                                Text(shop.detail)
                                    .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                            }

                            Spacer()

                            Image(systemName: selectedShopIDs.contains(shop.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(
                                    selectedShopIDs.contains(shop.id)
                                    ? Color(uiColor: .systemBlue)
                                    : AppTheme.Colors.tertiaryText
                                )
                        }
                        .padding(.horizontal, AppTheme.Spacing.large)
                        .padding(.vertical, AppTheme.Spacing.large)
                    }
                    .buttonStyle(.plain)
                    .background(selectionCard(isSelected: selectedShopIDs.contains(shop.id)))
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedShopIDs.contains(id) {
            selectedShopIDs.remove(id)
        } else {
            selectedShopIDs.insert(id)
        }
    }

    private func runRevealSequence() {
        revealSequence += 1
        let sequence = revealSequence

        guard isActive else {
            showsText = false
            return
        }

        showsText = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard revealSequence == sequence, isActive else { return }

            withAnimation(.easeOut(duration: 0.62)) {
                showsText = true
            }
        }
    }

    private func loadCoopStoresIfNeeded() async {
        guard hasLoadedStores == false else { return }
        await loadCoopStores(force: false)
    }

    private func loadCoopStores(force: Bool) async {
        guard force || hasLoadedStores == false else { return }
        guard isLoadingStores == false else { return }

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            shopOptions = OnboardingShopOption.previewSamples
            hasLoadedStores = true
            return
        }

        isLoadingStores = true
        storeLoadError = nil

        do {
            let stores = try await appServices.stores.fetchCompanyStores(
                companySlug: "coop",
                query: CompanyStoresQuery(limit: 10)
            )

            shopOptions = stores
                .filter { $0.detail != nil }
                .prefix(10)
                .map(OnboardingShopOption.init(store:))

            if selectedShopIDs.isEmpty {
                selectedShopIDs = Set(shopOptions.prefix(3).map(\.id))
            }

            hasLoadedStores = true
        } catch {
            storeLoadError = error.localizedDescription
        }

        isLoadingStores = false
    }

    private func selectionCard(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                    .strokeBorder(
                        Color(uiColor: isSelected ? .systemBlue : .separator),
                        lineWidth: 1
                    )
            }
    }
}

#Preview {
    OnboardingSubscriptionsView(
        isActive: false,
        address: "Malmö, Sweden",
        selectedShopIDs: .constant(Set(["1", "2"]))
    )
    .breezeScreen()
}
