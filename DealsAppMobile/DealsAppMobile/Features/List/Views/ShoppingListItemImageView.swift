import SwiftUI

struct ShoppingListItemImageView: View {
    let imageURL: String?
    let size: CGFloat
    var cornerRadius: CGFloat = AppTheme.Radii.medium

    var body: some View {
        Group {
            if let imageURL = imageURL, let url = safeImageURL(from: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack {
                            placeholder
                            ProgressView()
                                .tint(AppTheme.Colors.accent)
                        }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(AppTheme.Colors.borderStrong, lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppTheme.Colors.panelFillStrong)

            Image(systemName: "photo")
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
    }
}

private func safeImageURL(from value: String) -> URL? {
    if let direct = URL(string: value) {
        return direct
    }

    guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        return nil
    }

    return URL(string: encoded)
}
