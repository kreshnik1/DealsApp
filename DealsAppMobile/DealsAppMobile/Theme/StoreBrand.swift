import SwiftUI

/// Visual identity (colour + monogram) for a grocery chain, used to render a
/// consistent "company icon" wherever a store is shown. Sub-formats of the same
/// retailer (e.g. ICA Maxi / ICA Supermarket) resolve to the same `key` so they
/// can be grouped together.
struct StoreBrand: Equatable {
    /// Stable family key used to group sub-formats of the same retailer.
    let key: String
    /// Human-facing brand name, e.g. "ICA", "Coop", "Lidl".
    let name: String
    /// 1–3 character monogram rendered inside the brand chip.
    let monogram: String
    /// Gradient used to fill the brand chip, from the chain's real brand palette.
    let colors: [Color]

    var primary: Color { colors.first ?? StoreBrand.fallbackColors[0] }

    private static let fallbackColors = [
        Color(red: 0.22, green: 0.47, blue: 0.95),
        Color(red: 0.13, green: 0.20, blue: 0.52)
    ]

    init(chain: String) {
        let trimmed = chain.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        switch true {
        case normalized.contains("coop"):
            key = "coop"
            name = "Coop"
            monogram = "C"
            colors = [Color(red: 0.00, green: 0.65, blue: 0.34), Color(red: 0.00, green: 0.42, blue: 0.24)]
        case normalized.contains("ica"):
            key = "ica"
            name = "ICA"
            monogram = "ICA"
            colors = [Color(red: 0.89, green: 0.00, blue: 0.09), Color(red: 0.66, green: 0.00, blue: 0.06)]
        case normalized.contains("lidl"):
            key = "lidl"
            name = "Lidl"
            monogram = "L"
            colors = [Color(red: 0.00, green: 0.36, blue: 0.71), Color(red: 0.00, green: 0.20, blue: 0.46)]
        case normalized.contains("willys"):
            key = "willys"
            name = "Willys"
            monogram = "W"
            colors = [Color(red: 0.89, green: 0.00, blue: 0.13), Color(red: 0.55, green: 0.00, blue: 0.08)]
        case normalized.contains("hemkop"): // "hemköp" after diacritic folding
            key = "hemkop"
            name = "Hemköp"
            monogram = "H"
            colors = [Color(red: 0.85, green: 0.10, blue: 0.20), Color(red: 0.16, green: 0.44, blue: 0.26)]
        case normalized.contains("city") && normalized.contains("gross"):
            key = "citygross"
            name = "City Gross"
            monogram = "CG"
            colors = [Color(red: 0.82, green: 0.07, blue: 0.18), Color(red: 0.45, green: 0.03, blue: 0.10)]
        default:
            key = normalized.isEmpty ? "store" : normalized
            name = trimmed.isEmpty ? "Store" : trimmed.replacingOccurrences(of: "_", with: " ").capitalized
            monogram = String((trimmed.first.map(String.init) ?? "S")).uppercased()
            colors = StoreBrand.fallbackColors
        }
    }
}

/// Circular "company icon" chip rendering a chain's monogram over its brand gradient.
struct StoreBrandIcon: View {
    let brand: StoreBrand
    var size: CGFloat = 44

    var body: some View {
        Text(brand.monogram)
            .font(.system(size: monogramFontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: brand.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: brand.primary.opacity(0.35), radius: size * 0.16, x: 0, y: size * 0.07)
    }

    private var monogramFontSize: CGFloat {
        brand.monogram.count >= 3 ? size * 0.33 : size * 0.44
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(["STORA COOP", "ICA SUPERMARKET", "LIDL", "WILLYS", "Hemköp", "City Gross", "Tempo"], id: \.self) { chain in
            StoreBrandIcon(brand: StoreBrand(chain: chain))
        }
    }
    .padding()
}
