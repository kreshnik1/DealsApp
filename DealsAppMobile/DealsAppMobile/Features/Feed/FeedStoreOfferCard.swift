import SwiftUI

struct FeedStoreOfferCard: View {
    let store: StoreDTO
    let companySlug: String

    var body: some View {
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

    private var topPanel: some View {
        Rectangle()
            .fill(topPanelBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.Colors.borderStrong)
                    .frame(height: 1)
            }
        .frame(height: 96)
    }

    private var bottomPanel: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.large) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                logoBadge

                Text(displayName)
                    .breezeText(.bodyStrong)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            NavigationLink {
                StoreDetailView(store: store, companySlug: companySlug)
            } label: {
                Text("View")
            }
                .buttonStyle(AppButtonStyle(variant: .secondary, fillsWidth: false))
                .frame(minWidth: 96)
                .accessibilityHint("Open this store page.")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(minHeight: 92)
    }

    private var topPanelBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                AppTheme.Colors.panelFillStrong,
                AppTheme.Colors.heroEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var logoBadge: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.accentSoft)

            Text(logoText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accentStrong)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .padding(.horizontal, 8)
        }
        .frame(width: 46, height: 46)
        .overlay {
            Circle()
                .strokeBorder(AppTheme.Colors.activeBorder, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var logoText: String {
        let chain = store.chain.trimmingCharacters(in: .whitespacesAndNewlines)
        if chain.isEmpty {
            return "Store"
        }

        return chain.uppercased()
    }

    private var displayName: String {
        let trimmedName = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Unnamed Store" : trimmedName
    }
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
