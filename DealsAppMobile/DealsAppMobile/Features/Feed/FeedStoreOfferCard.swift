import SwiftUI

struct FeedStoreOfferCard: View {
    let store: StoreDTO
    let companySlug: String

    var body: some View {
        NavigationLink {
            StoreDetailView(store: store, companySlug: companySlug)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                topPanel
                bottomPanel
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous)
                    .fill(AppTheme.Colors.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous)
                            .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
                    )
            )
            .shadow(
                color: AppTheme.Shadows.ambient.color.opacity(0.55),
                radius: 24,
                x: 0,
                y: 12
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.xLarge, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open this store page.")
    }

    private var topPanel: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(topPanelBackground)

            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 150, height: 150)
                .blur(radius: 5)
                .offset(x: 170, y: -40)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                topMetaRow

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Text(displayName)
                        .font(AppTheme.Typography.pageTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(storeLocationLine)
                        .breezeText(.body, color: .white.opacity(0.84))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(22)
        }
        .frame(height: 188)
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                statPill(title: statusLine, systemImage: "clock")
                statPill(title: syncLine, systemImage: "arrow.clockwise")
            }

            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                    Text(store.chain.replacingOccurrences(of: "_", with: " "))
                        .breezeText(.meta, color: AppTheme.Colors.secondaryText)

                    Text(cardSummaryLine)
                        .breezeText(.bodyStrong)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Label("Open", systemImage: "arrow.up.forward")
                    .font(AppTheme.Typography.bodyEmphasis)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.tint(AppTheme.Colors.accentSoft2).interactive(), in: .capsule)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(minHeight: 126, alignment: .top)
    }

    private var topPanelBackground: some ShapeStyle {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var topMetaRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
            Label(chainLabel, systemImage: "star.fill")
                .font(AppTheme.Typography.meta)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .glassEffect(.regular.tint(.white.opacity(0.10)), in: .capsule)

            Spacer(minLength: 0)

            Label(editorialBadge, systemImage: "sparkles")
                .font(AppTheme.Typography.meta)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .glassEffect(.regular.tint(.white.opacity(0.10)), in: .capsule)
        }
    }

    private func statPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .breezeText(.meta, color: AppTheme.Colors.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .breezeSurface(
                fill: AppTheme.Colors.panelFillStrong,
                border: AppTheme.Colors.borderStrong,
                radius: AppTheme.Radii.phone
            )
    }

    private var gradientColors: [Color] {
        let normalized = chainLabel
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("coop") {
            return [
                Color(red: 0.09, green: 0.62, blue: 0.54),
                Color(red: 0.08, green: 0.20, blue: 0.43)
            ]
        }

        return [
            Color(red: 0.22, green: 0.47, blue: 0.95),
            Color(red: 0.15, green: 0.21, blue: 0.52)
        ]
    }

    private var chainLabel: String {
        let chain = store.chain.trimmingCharacters(in: .whitespacesAndNewlines)
        return chain.isEmpty ? "Store" : chain.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private var displayName: String {
        let trimmedName = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Unnamed Store" : trimmedName
    }

    private var editorialBadge: String {
        if store.detail?.city?.isEmpty == false {
            return "Near \(store.detail?.city ?? "")"
        }

        return "Saved Store"
    }

    private var storeLocationLine: String {
        let parts = [
            store.detail?.address?.trimmingCharacters(in: .whitespacesAndNewlines),
            store.detail?.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines),
            store.detail?.city?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { value -> String? in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }

        return parts.isEmpty ? "Store page with weekly deals and location details." : parts.joined(separator: " · ")
    }

    private var cardSummaryLine: String {
        if let city = store.detail?.city?.trimmingCharacters(in: .whitespacesAndNewlines), city.isEmpty == false {
            return "Browse the latest weekly offers for \(city)."
        }

        return "Browse the latest weekly offers and store details."
    }

    private var statusLine: String {
        StoreOpeningHoursResolver(
            regularHours: store.detail?.openingHours ?? [],
            specialHours: store.detail?.specialHours ?? []
        )
        .hoursText(for: .now) ?? "Hours unavailable"
    }

    private var syncLine: String {
        guard let updatedAt = store.detail?.updatedAt else {
            return "Recently synced"
        }

        return DateFormatter.feedCardUpdate.string(from: updatedAt)
    }
}

private extension DateFormatter {
    static let feedCardUpdate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    FeedStoreOfferCard(
        store: StoreDTO(
            id: 1,
            companyID: 1,
            name: "Coop Aby",
            chain: "COOP",
            externalID: "coop:coop:coop-aby",
            storeURL: nil,
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
                    OpeningHoursEntryDTO(days: ["Monday", "Tuesday"], open: "07:00", close: "22:00"),
                    OpeningHoursEntryDTO(days: ["Sunday"], open: "08:00", close: "22:00")
                ],
                specialHours: nil,
                scrapedAt: .now,
                updatedAt: .now
            )
        ),
        companySlug: "coop"
    )
    .padding()
    .background(AppThemeBackground())
}
