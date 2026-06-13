import SwiftUI

struct OnboardingSubscriptionsView: View {
    @Environment(\.appServices) private var appServices

    let isActive: Bool
    let address: String
    let locationCoordinates: UserLocationCoordinates?
    @State private var showsText = false
    @State private var revealSequence = 0
    @State private var revealTask: Task<Void, Never>?
    @State private var shopOptions: [OnboardingShopOption] = []
    @State private var loadedCoordinates: UserLocationCoordinates?
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
        .task(id: loadTrigger) {
            guard isActive else { return }
            await loadNearbyStoresIfNeeded()
        }
    }

    private var loadTrigger: String {
        guard let locationCoordinates else {
            return "\(isActive)-missing"
        }

        return "\(isActive)-\(locationCoordinates.latitude)-\(locationCoordinates.longitude)"
    }

    private var subtitle: String {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAddress.isEmpty {
            return "Choose a few stores to start."
        }

        return "Closest stores to \(trimmedAddress)"
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingStores && shopOptions.isEmpty {
            ProgressView("Loading nearby stores...")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .padding(.vertical, AppTheme.Spacing.xxLarge)
        } else if let storeLoadError, shopOptions.isEmpty {
            VStack(spacing: AppTheme.Spacing.medium) {
                Text("Could not load nearby stores.")
                    .breezeText(.bodyStrong)

                Text(storeLoadError)
                    .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task {
                        await loadNearbyStores(force: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.xxLarge)
            .background(selectionCard(isSelected: false))
        } else if shopOptions.isEmpty {
            Text("No nearby stores are available yet.")
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
        revealTask?.cancel()

        guard isActive else {
            showsText = false
            return
        }

        showsText = false

        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard Task.isCancelled == false, revealSequence == sequence, isActive else { return }

            withAnimation(.easeOut(duration: 0.62)) {
                showsText = true
            }
        }
    }

    private func loadNearbyStoresIfNeeded() async {
        await loadNearbyStores(force: false)
    }

    private func loadNearbyStores(force: Bool) async {
        guard let locationCoordinates else {
            shopOptions = []
            storeLoadError = nil
            loadedCoordinates = nil
            return
        }

        guard force || loadedCoordinates != locationCoordinates || shopOptions.isEmpty else { return }
        guard isLoadingStores == false else { return }

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            shopOptions = OnboardingShopOption.previewSamples
            loadedCoordinates = locationCoordinates
            return
        }

        isLoadingStores = true
        storeLoadError = nil

        do {
            let stores = try await appServices.stores.fetchNearbyStores(
                NearbyStoresQuery(
                    latitude: locationCoordinates.latitude,
                    longitude: locationCoordinates.longitude,
                    limit: 12
                )
            )

            shopOptions = stores
                .filter { $0.detail != nil }
                .prefix(12)
                .map(OnboardingShopOption.init(store:))

            selectedShopIDs.formIntersection(Set(shopOptions.map(\.id)))
            loadedCoordinates = locationCoordinates
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
        locationCoordinates: UserLocationCoordinates(latitude: 55.605, longitude: 13.0038),
        selectedShopIDs: .constant(Set(["1", "2"]))
    )
    .breezeScreen()
}
