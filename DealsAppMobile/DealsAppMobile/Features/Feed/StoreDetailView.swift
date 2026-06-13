import SwiftData
import SwiftUI

struct StoreDetailView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    let store: StoreDTO
    let companySlug: String

    @Namespace private var offersTransitionNamespace

    @State private var offers: [DealDTO] = []
    @State private var isLoadingOffers = false
    @State private var offersError: String?
    @State private var hasLoadedOffers = false
    @State private var offersLayout: StoreOffersLayout = .list
    @State private var recentlyAddedOfferIDs = Set<Int>()
    @State private var toastState: DealToastState?

    var body: some View {
        ZStack {
            AppThemeBackground()
                .ignoresSafeArea()

            StoreTintBackground(color: headerTintColor)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                    headerSection
                    quickActionsSection
                    // Temporarily hidden while today's opening hours are surfaced in the header.
                    // storeSummarySection
                    // openingHoursSection
                    offersSection
                }
                .padding(.horizontal, AppTheme.Spacing.screenInset)
                .padding(.top, 24)
                .padding(.bottom, AppTheme.Spacing.xxLarge)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share store", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .task(id: offersTaskID) {
            await loadOffers()
        }
        .overlay(alignment: .top) {
            if let toastState {
                DealToastView(state: toastState)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22, extraBounce: 0), value: toastState?.id)
        .task(id: toastState?.id) {
            guard let toastState else {
                return
            }

            try? await Task.sleep(for: .seconds(4))

            guard self.toastState?.id == toastState.id else {
                return
            }

            withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                self.toastState = nil
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(headerBadgeFill)
                .frame(width: 112, height: 112)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(headerBadgeBorder, lineWidth: 1)
                }
                .overlay {
                    Text(storeMonogram)
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(headerPrimaryText)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)

            VStack(spacing: AppTheme.Spacing.small) {
                Text(chainLabel)
                    .breezeText(.meta, color: headerSecondaryText)

                Text(store.name)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(headerPrimaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(headerSubtitle)
                    .breezeText(.body, color: headerSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppTheme.Spacing.small) {
                    metaPill(todayStatusLine, systemImage: "clock")

                    if let city = store.detail?.city, city.isEmpty == false {
                        metaPill(city, systemImage: "mappin.and.ellipse")
                    }
                }
                .padding(.top, AppTheme.Spacing.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var quickActionsSection: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            actionButton(
                title: "Directions",
                variant: .primary,
                url: mapsURL
            )

            actionButton(
                title: "Store Site",
                variant: .secondary,
                url: storePageURL
            )
        }
    }

    private var storeSummarySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            sectionHeader("Store Overview")

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                infoRow(
                    title: "Address",
                    value: composedAddress ?? "Address not available",
                    systemImage: "location.fill"
                )

                infoRow(
                    title: "Phone",
                    value: store.detail?.phone ?? "Phone not available",
                    systemImage: "phone.fill"
                )

                infoRow(
                    title: "Updated",
                    value: updatedLine,
                    systemImage: "arrow.clockwise"
                )
            }
            .padding(20)
            .breezeSurface(fill: AppTheme.Colors.panelFill, border: AppTheme.Colors.borderStrong, radius: AppTheme.Radii.xLarge)
        }
    }

    private var offersSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            offersSectionHeader

            Group {
                if isLoadingOffers && hasLoadedOffers == false {
                    offersLoadingState
                } else if let offersError, offers.isEmpty {
                    offersErrorState(message: offersError)
                } else if offers.isEmpty {
                    offersEmptyState
                } else {
                    offersContent
                }
            }
        }
    }

    @ViewBuilder
    private var openingHoursSection: some View {
        if let openingHours = store.detail?.openingHours, openingHours.isEmpty == false {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                sectionHeader("Opening Hours")

                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    ForEach(Array(openingHours.enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                            Text(entry.days.joined(separator: ", "))
                                .breezeText(.bodyStrong)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(hoursLabel(for: entry))
                                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        }

                        if entry.days != openingHours.last?.days {
                            Divider()
                                .overlay(AppTheme.Colors.borderStrong)
                        }
                    }
                }
                .padding(20)
                .breezeSurface(fill: AppTheme.Colors.panelFill, border: AppTheme.Colors.borderStrong, radius: AppTheme.Radii.xLarge)
            }
        }
    }

    private var offersLoadingState: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Loading store offers")
                .breezeText(.bodyStrong)

            ProgressView()
                .tint(AppTheme.Colors.accent)

            Text("Fetching the latest deals for this store.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .breezeSurface(fill: AppTheme.Colors.panelFill, border: AppTheme.Colors.borderStrong, radius: AppTheme.Radii.xLarge)
    }

    private func offersErrorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Could not load offers.")
                .breezeText(.bodyStrong)

            Text(message)
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("Try Again") {
                Task {
                    await loadOffers(force: true)
                }
            }
            .buttonStyle(.glass)
        }
        .padding(20)
        .breezeSurface(fill: AppTheme.Colors.panelFill, border: AppTheme.Colors.borderStrong, radius: AppTheme.Radii.xLarge)
    }

    private var offersEmptyState: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("No offers available for this store.")
                .breezeText(.bodyStrong)

            Text("Check back after the next sync to see store-specific deals here.")
                .breezeText(.body, color: AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .breezeSurface(fill: AppTheme.Colors.panelFill, border: AppTheme.Colors.borderStrong, radius: AppTheme.Radii.xLarge)
    }

    private var offersList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            ForEach(Array(offers.enumerated()), id: \.element.id) { index, offer in
                offerRow(offer)

                if index != offers.index(before: offers.endIndex) {
                    Divider()
                        .overlay(AppTheme.Colors.borderStrong)
                }
            }
        }
        .padding(20)
        .breezeSurface(fill: AppTheme.Colors.panelFill, border: AppTheme.Colors.borderStrong, radius: AppTheme.Radii.xLarge)
    }

    private var offersGrid: some View {
        LazyVGrid(columns: offersGridColumns, spacing: AppTheme.Spacing.medium) {
            ForEach(offers, id: \.id) { offer in
                offerGridCard(offer)
            }
        }
        .padding(.vertical, 4)
    }

    private var headerTintColor: Color {
        Color(red: 0.10, green: 0.71, blue: 0.57)
    }

    private var offersGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 28, alignment: .top),
            GridItem(.flexible(), spacing: 28, alignment: .top)
        ]
    }

    private var offersTaskID: String {
        "\(companySlug)-\(store.id)"
    }

    private var headerPrimaryText: Color {
        colorScheme == .dark ? .white : AppTheme.Colors.primaryText
    }

    private var headerSecondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.82) : AppTheme.Colors.secondaryText
    }

    private var headerBadgeFill: Color {
        colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.26)
    }

    private var headerBadgeBorder: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .white.opacity(0.42)
    }

    private var chainLabel: String {
        store.chain.replacingOccurrences(of: "_", with: " ")
    }

    private var headerSubtitle: String {
        [
            store.detail?.address,
            store.detail?.postalCode,
            store.detail?.city
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }
        .joined(separator: " · ")
    }

    private var todayStatusLine: String {
        todayOpeningHoursText ?? "Hours unavailable"
    }

    private var composedAddress: String? {
        [
            store.detail?.address,
            store.detail?.postalCode,
            store.detail?.city
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }
        .joined(separator: ", ")
        .nilIfEmpty
    }

    private var updatedLine: String {
        guard let updatedAt = store.detail?.updatedAt else {
            return "Recently synced"
        }

        return DateFormatter.storeUpdated.string(from: updatedAt)
    }

    private var mapsURL: URL? {
        if let googleMapsURL = safeURL(from: store.detail?.googleMapsURL) {
            return googleMapsURL
        }

        if let latitude = store.detail?.latitude, let longitude = store.detail?.longitude {
            return URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)")
        }

        if let address = composedAddress?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "http://maps.apple.com/?q=\(address)")
        }

        return nil
    }

    private var storePageURL: URL? {
        safeURL(from: store.storeURL)
            ?? safeURL(from: store.weeklyDealsURL)
    }

    private var shareURL: URL? {
        storePageURL ?? mapsURL
    }

    private var storeMonogram: String {
        let parts = store.name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }

        return parts.isEmpty ? "C" : parts.joined()
    }

    private var todayOpeningHoursText: String? {
        guard let detail = store.detail else {
            return nil
        }

        return StoreOpeningHoursResolver(
            regularHours: detail.openingHours ?? [],
            specialHours: detail.specialHours ?? []
        )
        .hoursText(for: .now)
    }

    private var offersSectionHeader: some View {
        sectionHeader("Offers") {
            offersLayoutToggle
        }
    }

    @ViewBuilder
    private var offersContent: some View {
        Group {
            switch offersLayout {
            case .list:
                offersList
            case .grid:
                offersGrid
            }
        }
        .animation(.snappy(duration: 0.42, extraBounce: 0.04), value: offersLayout)
    }

    private func offerRow(_ offer: DealDTO) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
            offerThumbnail(for: offer, size: 72)
                .matchedGeometryEffect(id: "offer-thumbnail-\(offer.id)", in: offersTransitionNamespace)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                    offerSummary(offer, supportingLineLimit: nil)
                        .matchedGeometryEffect(id: "offer-summary-\(offer.id)", in: offersTransitionNamespace, properties: .position)

                    Spacer(minLength: 0)

                    offerPriceSummary(for: offer, alignment: .trailing)
                        .matchedGeometryEffect(id: "offer-price-\(offer.id)", in: offersTransitionNamespace, properties: .position)
                }

                offerAddToListButton(for: offer)
            }
        }
        .matchedGeometryEffect(id: "offer-container-\(offer.id)", in: offersTransitionNamespace)
    }

    private func offerGridCard(_ offer: DealDTO) -> some View {
        VStack(spacing: 0) {
            offerGridMedia(for: offer)
                .matchedGeometryEffect(id: "offer-thumbnail-\(offer.id)", in: offersTransitionNamespace)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                offerSummary(offer, supportingLineLimit: 3)
                    .matchedGeometryEffect(id: "offer-summary-\(offer.id)", in: offersTransitionNamespace, properties: .position)

                Spacer(minLength: 0)

                offerPriceSummary(for: offer, alignment: .leading)
                    .matchedGeometryEffect(id: "offer-price-\(offer.id)", in: offersTransitionNamespace, properties: .position)

                offerAddToListButton(for: offer)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(AppTheme.Colors.panelFillStrong)
        }
        .frame(maxWidth: .infinity, minHeight: 324, alignment: .topLeading)
        .background(AppTheme.Colors.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous)
                .fill(AppTheme.Colors.panelFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous)
                .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
        }
        .matchedGeometryEffect(id: "offer-container-\(offer.id)", in: offersTransitionNamespace)
    }

    @ViewBuilder
    private func offerThumbnail(for offer: DealDTO, size: CGFloat) -> some View {
        if let imageURL = safeURL(from: offer.imageURL) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    thumbnailPlaceholder(size: size)
                case .empty:
                    ZStack {
                        thumbnailPlaceholder(size: size)
                        ProgressView()
                            .tint(AppTheme.Colors.accent)
                    }
                @unknown default:
                    thumbnailPlaceholder(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous)
                    .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
            }
        } else {
            thumbnailPlaceholder(size: size)
        }
    }

    private func offerGridMedia(for offer: DealDTO) -> some View {
        Group {
            if let imageURL = safeURL(from: offer.imageURL) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        gridMediaPlaceholder
                    case .empty:
                        ZStack {
                            gridMediaPlaceholder
                            ProgressView()
                                .tint(AppTheme.Colors.accent)
                        }
                    @unknown default:
                        gridMediaPlaceholder
                    }
                }
            } else {
                gridMediaPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 182)
        .clipped()
    }

    private var gridMediaPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.panelFillMuted,
                    AppTheme.Colors.panelFill
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
    }

    private func thumbnailPlaceholder(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous)
                .fill(AppTheme.Colors.panelFillStrong)

            Image(systemName: "photo")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radii.medium, style: .continuous)
                .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
        }
    }

    private func hoursLabel(for entry: OpeningHoursEntryDTO, prefix: String? = nil) -> String {
        let value: String

        switch (entry.open, entry.close) {
        case let (open?, close?):
            value = "\(open)-\(close)"
        case let (open?, nil):
            value = "Opens at \(open)"
        case let (nil, close?):
            value = "Closes at \(close)"
        default:
            value = "See store"
        }

        if let prefix {
            return "\(prefix) \(value)"
        }

        return value
    }

    private func metaPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AppTheme.Typography.meta)
            .foregroundStyle(headerPrimaryText.opacity(colorScheme == .dark ? 0.92 : 0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.34))
            )
            .overlay {
                Capsule()
                    .strokeBorder(colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(0.38), lineWidth: 1)
            }
    }

    private func sectionHeader(_ title: String) -> some View {
        sectionHeader(title) {
            EmptyView()
        }
    }

    private func sectionHeader<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Text(title)
                .breezeText(.section, color: AppTheme.Colors.primaryText)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText.opacity(0.78))

            Spacer(minLength: 0)

            trailing()
        }
    }

    private var offersLayoutToggle: some View {
        HStack(spacing: 6) {
            ForEach(StoreOffersLayout.allCases) { layout in
                Button {
                    withAnimation(.snappy(duration: 0.42, extraBounce: 0.04)) {
                        offersLayout = layout
                    }
                } label: {
                    Image(systemName: layout.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(offersLayout == layout ? AppTheme.Colors.primaryText : AppTheme.Colors.secondaryText)
                        .frame(width: 34, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(offersLayout == layout ? AppTheme.Colors.panelFillStrong : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(layout.accessibilityLabel)
                .accessibilityValue(offersLayout == layout ? "Selected" : "Not selected")
            }
        }
        .padding(4)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.Colors.panelFill)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
        }
    }

    private func offerSummary(_ offer: DealDTO, supportingLineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
            if let brand = offer.brand?.nilIfEmpty {
                Text(brand)
                    .breezeText(.meta, color: AppTheme.Colors.tertiaryText)
            }

            Text(offer.name)
                .breezeText(.bodyStrong)
                .fixedSize(horizontal: false, vertical: true)

            if let supporting = offerSupportingLine(for: offer) {
                Text(supporting)
                    .breezeText(.body, color: AppTheme.Colors.secondaryText)
                    .lineLimit(supportingLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let validToLine = validToLine(for: offer) {
                Text(validToLine)
                    .breezeText(.meta, color: AppTheme.Colors.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func offerPriceSummary(
        for offer: DealDTO,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: AppTheme.Spacing.xxSmall) {
            if let membershipPriceLabel = membershipPriceLabel(for: offer) {
                Text(membershipPriceLabel)
                    .breezeText(.caption, color: AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(textAlignment(for: alignment))
            }

            if let priceLine = primaryPriceLine(for: offer) {
                Text(priceLine)
                    .breezeText(.bodyStrong)
                    .multilineTextAlignment(textAlignment(for: alignment))
            }

            if let originalPriceLine = originalPriceLine(for: offer) {
                Text(originalPriceLine)
                    .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(textAlignment(for: alignment))
            }
        }
    }

    @ViewBuilder
    private func offerAddToListButton(for offer: DealDTO) -> some View {
        let isAdded = recentlyAddedOfferIDs.contains(offer.id)

        if isAdded {
            Button {
                addOfferToList(offer)
            } label: {
                Label("Added", systemImage: "checkmark")
                    .breezeText(.bodyStrong, color: AppTheme.Colors.accentStrong)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .buttonStyle(.glass)
            .disabled(true)
            .accessibilityHint("This deal is already in your shopping list.")
        } else {
            Button {
                addOfferToList(offer)
            } label: {
                Label("Add to list", systemImage: "plus")
                    .breezeText(.bodyStrong, color: AppTheme.Colors.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .buttonStyle(.glassProminent)
            .accessibilityHint("Add this deal to your shopping list.")
        }
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                Text(title)
                    .breezeText(.meta, color: AppTheme.Colors.tertiaryText)

                Text(value)
                    .breezeText(.bodyStrong)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func actionButton(title: String, variant: AppButtonVariant, url: URL?) -> some View {
        if variant == .primary {
            Button(title) {
                guard let url else { return }
                openURL(url)
            }
            .buttonStyle(.glassProminent)
            .disabled(url == nil)
            .opacity(url == nil ? 0.56 : 1)
        } else {
            Button(title) {
                guard let url else { return }
                openURL(url)
            }
            .buttonStyle(.glass)
            .disabled(url == nil)
            .opacity(url == nil ? 0.56 : 1)
        }
    }

    private func loadOffers(force: Bool = false) async {
        guard isLoadingOffers == false else {
            return
        }

        guard force || hasLoadedOffers == false else {
            return
        }

        isLoadingOffers = true
        offersError = nil

        do {
            offers = try await appServices.deals.fetchStoreDeals(
                companySlug: companySlug,
                storeID: store.id,
                query: StoreDealsQuery(hydrateIfEmpty: true, limit: 20, offset: 0)
            )
            hasLoadedOffers = true
        } catch {
            offers = []
            offersError = error.localizedDescription
            hasLoadedOffers = true
        }

        isLoadingOffers = false
    }

    private func primaryPriceLine(for offer: DealDTO) -> String? {
        if let priceLabel = offer.priceLabel?.nilIfEmpty, isStandaloneMembershipLabel(priceLabel) == false {
            return priceLabel
        }

        if let dealPrice = offer.dealPrice {
            return NumberFormatter.storePrice.string(from: NSNumber(value: dealPrice))
        }

        return nil
    }

    private func originalPriceLine(for offer: DealDTO) -> String? {
        guard let originalPrice = offer.originalPrice else {
            return nil
        }

        guard let formatted = NumberFormatter.storePrice.string(from: NSNumber(value: originalPrice)) else {
            return nil
        }

        return "Ord. \(formatted)"
    }

    private func offerSupportingLine(for offer: DealDTO) -> String? {
        let detail = offer.dealText?.nilIfEmpty
            ?? offer.extraInfo?.nilIfEmpty
            ?? offer.description?.nilIfEmpty

        if let size = offer.size?.nilIfEmpty, let detail {
            return "\(size) · \(detail)"
        }

        return offer.size?.nilIfEmpty ?? detail
    }

    private func validToLine(for offer: DealDTO) -> String? {
        guard let validTo = offer.validTo else {
            return nil
        }

        return "Valid until \(DateFormatter.offerValidity.string(from: validTo))"
    }

    private func membershipPriceLabel(for offer: DealDTO) -> String? {
        guard offer.isMembershipPrice else {
            return nil
        }

        if let priceLabel = offer.priceLabel?.nilIfEmpty, isStandaloneMembershipLabel(priceLabel) {
            return priceLabel
        }

        return "MEDLEMSPRIS"
    }

    private func isStandaloneMembershipLabel(_ value: String) -> Bool {
        let normalizedValue = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let membershipTerms = ["medlemspris", "membership price", "member price"]
        let hasMembershipTerm = membershipTerms.contains { normalizedValue.contains($0) }
        let hasDigits = normalizedValue.rangeOfCharacter(from: .decimalDigits) != nil

        return hasMembershipTerm && hasDigits == false
    }

    private func textAlignment(for alignment: HorizontalAlignment) -> TextAlignment {
        switch alignment {
        case .leading:
            .leading
        case .trailing:
            .trailing
        default:
            .center
        }
    }

    private var shoppingListMutations: ShoppingListMutationService {
        ShoppingListMutationService(context: modelContext)
    }

    private func addOfferToList(_ offer: DealDTO) {
        do {
            try shoppingListMutations.createItem(from: offer, store: store)
            recentlyAddedOfferIDs.insert(offer.id)
            presentToast(
                title: "Added to your list",
                message: offer.name,
                kind: .success
            )
        } catch {
            presentToast(
                title: "Could not add item",
                message: error.localizedDescription,
                kind: .error
            )
        }
    }

    private func presentToast(title: String, message: String?, kind: DealToastState.Kind) {
        withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
            toastState = DealToastState(
                title: title,
                message: message,
                kind: kind
            )
        }
    }
}

private extension DateFormatter {
    static let storeUpdated: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        return formatter
    }()

    static let offerValidity: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        return formatter
    }()
}

private extension NumberFormatter {
    static let storePrice: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "SEK"
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private nonisolated func safeURL(from value: String?) -> URL? {
    guard let value else {
        return nil
    }

    if let direct = URL(string: value) {
        return direct
    }

    guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        return nil
    }

    return URL(string: encoded)
}

#Preview {
    NavigationStack {
        StoreDetailView(
            store: StoreDTO(
                id: 1,
                companyID: 1,
                name: "Coop Aby",
                chain: "COOP",
                externalID: "coop:coop:coop-aby",
                storeURL: "https://www.coop.se/butiker-erbjudanden/coop/coop-aby/om-butiken/",
                weeklyDealsURL: nil,
                detail: StoreDetailDTO(
                    id: 1,
                    storeID: 1,
                    aboutURL: nil,
                    address: "Nykopingsvagen 18-22",
                    postalCode: "61630",
                    city: "Aby",
                    phone: "010-7414740",
                    googleMapsURL: nil,
                    latitude: 58.66,
                    longitude: 16.18,
                    openingHours: [
                        OpeningHoursEntryDTO(days: ["måndag", "tisdag"], open: "07:00", close: "22:00"),
                        OpeningHoursEntryDTO(days: ["söndag"], open: "08:00", close: "22:00")
                    ],
                    specialHours: nil,
                    scrapedAt: .now,
                    updatedAt: .now
                )
            ),
            companySlug: "coop"
        )
    }
    .modelContainer(AppPreviewContainer.shoppingList)
}
