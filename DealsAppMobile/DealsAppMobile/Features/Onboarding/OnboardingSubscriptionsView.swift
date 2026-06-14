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
    @State private var collapsedGroups: Set<String> = []
    @Binding var selectedShopIDs: Set<String>

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.xxLarge) {
                Spacer(minLength: 72)

                header
                    .opacity(showsText ? 1 : 0)
                    .blur(radius: showsText ? 0 : 10)
                    .offset(y: showsText ? 0 : 24)

                content
                    .frame(maxWidth: 460)
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

    private var header: some View {
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

            if selectedShopIDs.isEmpty == false {
                Label("\(selectedShopIDs.count) selected", systemImage: "checkmark.seal.fill")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.accentStrong)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.Colors.accentSoft))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
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
            return "Pick the stores you shop at to follow their weekly deals."
        }

        return "Stores closest to \(trimmedAddress)"
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingStores && shopOptions.isEmpty {
            ProgressView("Loading nearby stores…")
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
            .frame(maxWidth: .infinity)
            .background(cardSurface)
        } else if shopOptions.isEmpty {
            Text("No nearby stores are available yet.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .padding(.vertical, AppTheme.Spacing.xxLarge)
        } else {
            LazyVStack(spacing: AppTheme.Spacing.xLarge) {
                ForEach(groupedShops) { group in
                    groupCard(group)
                }
            }
        }
    }

    // MARK: - Grouped store cards

    private func groupCard(_ group: ShopGroup) -> some View {
        let isExpanded = collapsedGroups.contains(group.id) == false

        return VStack(spacing: 0) {
            groupHeader(group, isExpanded: isExpanded)

            if isExpanded {
                Divider()
                    .overlay(AppTheme.Colors.border)

                ForEach(Array(group.shops.enumerated()), id: \.element.id) { index, shop in
                    if index > 0 {
                        Divider()
                            .overlay(AppTheme.Colors.border)
                            .padding(.leading, AppTheme.Spacing.large)
                    }
                    shopRow(shop)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                .fill(AppTheme.Colors.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous))
        .shadow(color: AppTheme.Shadows.ambient.color.opacity(0.4), radius: 18, x: 0, y: 10)
    }

    private func groupHeader(_ group: ShopGroup, isExpanded: Bool) -> some View {
        let selectedCount = group.shops.filter { selectedShopIDs.contains($0.id) }.count
        let allSelected = selectedCount == group.shops.count

        return HStack(spacing: AppTheme.Spacing.medium) {
            Button {
                toggleCollapse(group.id)
            } label: {
                HStack(spacing: AppTheme.Spacing.medium) {
                    StoreBrandIcon(brand: group.brand, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.brand.name)
                            .breezeText(.bodyStrong)
                        Text(headerSubtitle(group, selectedCount: selectedCount))
                            .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: AppTheme.Spacing.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                toggleGroup(group, selectAll: allSelected == false)
            } label: {
                Text(allSelected ? "Clear" : "Select all")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(group.brand.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(group.brand.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Button {
                toggleCollapse(group.id)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(group.brand.name) stores" : "Expand \(group.brand.name) stores")
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.large)
    }

    private func headerSubtitle(_ group: ShopGroup, selectedCount: Int) -> String {
        if selectedCount > 0 {
            return "\(group.subtitle) · \(selectedCount) selected"
        }
        return group.subtitle
    }

    private func shopRow(_ shop: OnboardingShopOption) -> some View {
        let isSelected = selectedShopIDs.contains(shop.id)

        return Button {
            toggle(shop.id)
        } label: {
            HStack(spacing: AppTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(shop.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: AppTheme.Spacing.small) {
                        if shop.addressLine.isEmpty == false {
                            Label(shop.addressLine, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                        }

                        Spacer(minLength: 6)

                        if let distanceText = shop.distanceText {
                            distancePill(distanceText, tint: shop.brand.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? shop.brand.primary : AppTheme.Colors.tertiaryText)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(isSelected ? shop.brand.primary.opacity(0.07) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func distancePill(_ text: String, tint: Color) -> some View {
        Label(text, systemImage: "location.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.12)))
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
            .fill(AppTheme.Colors.panelFill)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                    .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
            }
    }

    // MARK: - Grouping

    private var groupedShops: [ShopGroup] {
        Dictionary(grouping: shopOptions) { StoreBrand(chain: $0.chain).key }
            .compactMap { _, shops -> ShopGroup? in
                guard let first = shops.first else { return nil }
                let sorted = shops.sorted {
                    ($0.distanceKM ?? .greatestFiniteMagnitude) < ($1.distanceKM ?? .greatestFiniteMagnitude)
                }
                let brand = StoreBrand(chain: first.chain)
                return ShopGroup(id: brand.key, brand: brand, shops: sorted)
            }
            .sorted { $0.nearestDistance < $1.nearestDistance }
    }

    private struct ShopGroup: Identifiable {
        let id: String
        let brand: StoreBrand
        let shops: [OnboardingShopOption]

        var nearestDistance: Double {
            shops.compactMap(\.distanceKM).min() ?? .greatestFiniteMagnitude
        }

        var subtitle: String {
            let storesText = shops.count == 1 ? "1 store" : "\(shops.count) stores"
            if let nearest = shops.compactMap(\.distanceText).first {
                return "\(storesText) · from \(nearest)"
            }
            return storesText
        }
    }

    // MARK: - Selection

    private func toggle(_ id: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if selectedShopIDs.contains(id) {
                selectedShopIDs.remove(id)
            } else {
                selectedShopIDs.insert(id)
            }
        }
    }

    private func toggleCollapse(_ groupID: String) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if collapsedGroups.contains(groupID) {
                collapsedGroups.remove(groupID)
            } else {
                collapsedGroups.insert(groupID)
            }
        }
    }

    private func toggleGroup(_ group: ShopGroup, selectAll: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
            for shop in group.shops {
                if selectAll {
                    selectedShopIDs.insert(shop.id)
                } else {
                    selectedShopIDs.remove(shop.id)
                }
            }
        }
    }

    // MARK: - Reveal animation

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

    // MARK: - Loading

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
}

#Preview {
    OnboardingSubscriptionsView(
        isActive: true,
        address: "Malmö, Sweden",
        locationCoordinates: UserLocationCoordinates(latitude: 55.605, longitude: 13.0038),
        selectedShopIDs: .constant(Set(["1", "3"]))
    )
    .breezeScreen()
}
