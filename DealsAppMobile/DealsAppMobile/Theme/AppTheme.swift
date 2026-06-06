import SwiftUI

enum AppTheme {
    static let brandEyebrow = "BREEZE"

    enum Colors {
        static let screenBase = Color.adaptive(light: 0xF7F1E7, dark: 0x0E0E12)
        static let screenSecondary = Color.adaptive(light: 0xFFFCF7, dark: 0x16161C)
        static let primaryText = Color.adaptive(light: 0x181712, dark: 0xF5F4F0)
        static let secondaryText = Color.adaptive(light: 0x4F493F, dark: 0xBDBBB5)
        static let tertiaryText = Color.adaptive(light: 0x7A7267, dark: 0x777875)
        static let buttonPrimaryText = Color.adaptive(light: 0x181712, dark: 0x0E0E12)

        static let accent = Color.adaptive(light: 0xD6B156, dark: 0xE8C97A)
        static let accentStrong = Color.adaptive(light: 0x8E6A17, dark: 0xC9A84C)
        static let accentSoft = Color.adaptive(light: 0xB68421, dark: 0xE8C97A, lightAlpha: 0.16, darkAlpha: 0.14)
        static let accentSoft2 = Color.adaptive(light: 0xB68421, dark: 0xE8C97A, lightAlpha: 0.09, darkAlpha: 0.07)

        static let panelFill = Color.adaptive(light: 0xFFFCF7, dark: 0x16161C)
        static let panelFillStrong = Color.adaptive(light: 0xF1E8DA, dark: 0x1E1E26)
        static let panelFillMuted = Color.adaptive(light: 0xE4D9C4, dark: 0x26262F)

        static let border = Color.adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.07)
        static let borderStrong = Color.adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.12)
        static let activeBorder = Color.adaptive(light: 0xB68421, dark: 0xE8C97A, lightAlpha: 0.26, darkAlpha: 0.25)

        static let heroStart = Color.adaptive(light: 0xFFF8EA, dark: 0x21212A)
        static let heroEnd = Color.adaptive(light: 0xF1E8DA, dark: 0x121218)
        static let textFieldFill = Color.adaptive(light: 0xF1E8DA, dark: 0x1E1E26)
        static let footerShade = Color.adaptive(light: 0xFFF8EA, dark: 0x000000, lightAlpha: 0.92, darkAlpha: 0.22)
    }

    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let xxLarge: CGFloat = 28
        static let section: CGFloat = 28
        static let screenInset: CGFloat = 24
    }

    enum Radii {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let xLarge: CGFloat = 28
        static let phone: CGFloat = 44
        static let capsule: CGFloat = 999
    }

    enum Typography {
        static let hero = Font.system(size: 42, weight: .bold)
        static let pageTitle = Font.system(size: 28, weight: .bold)
        static let sectionTitle = Font.system(size: 20, weight: .semibold)
        static let cardTitle = Font.system(size: 15, weight: .bold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodyEmphasis = Font.system(size: 15, weight: .semibold)
        static let caption = Font.system(size: 10, weight: .semibold)
        static let eyebrow = Font.system(size: 11, weight: .bold)
        static let meta = Font.system(size: 11, weight: .regular)
    }

    enum Shadows {
        static let ambient = ShadowStyle(
            color: Color.adaptive(light: 0x73561A, dark: 0x000000, lightAlpha: 0.14, darkAlpha: 0.28),
            radius: 30,
            x: 0,
            y: -2
        )
    }

    enum IconSizes {
        static let toolbar: CGFloat = 18
        static let tab: CGFloat = 20
        static let hero: CGFloat = 24
    }

    enum Materials {
        static let panel = Glass.regular.tint(Colors.accentSoft2)
        static let feature = Glass.regular.tint(Colors.accentSoft)
        static let interactive = Glass.regular.tint(Colors.accentSoft).interactive()
    }
}

enum AppTextStyle {
    case hero
    case title
    case section
    case body
    case bodyStrong
    case eyebrow
    case meta
    case caption

    var font: Font {
        switch self {
        case .hero:
            AppTheme.Typography.hero
        case .title:
            AppTheme.Typography.pageTitle
        case .section:
            AppTheme.Typography.sectionTitle
        case .body:
            AppTheme.Typography.body
        case .bodyStrong:
            AppTheme.Typography.bodyEmphasis
        case .eyebrow:
            AppTheme.Typography.eyebrow
        case .meta:
            AppTheme.Typography.meta
        case .caption:
            AppTheme.Typography.caption
        }
    }

    var tracking: CGFloat {
        switch self {
        case .hero:
            -1.5
        case .title:
            -0.5
        case .section:
            -0.3
        case .body, .bodyStrong, .meta:
            0
        case .eyebrow:
            1.1
        case .caption:
            0.8
        }
    }
}

enum AppButtonVariant {
    case primary
    case secondary

    fileprivate var foreground: Color {
        switch self {
        case .primary:
            AppTheme.Colors.buttonPrimaryText
        case .secondary:
            AppTheme.Colors.primaryText
        }
    }

    fileprivate var background: Color {
        switch self {
        case .primary:
            AppTheme.Colors.accent
        case .secondary:
            AppTheme.Colors.panelFillStrong
        }
    }

    fileprivate var border: Color {
        switch self {
        case .primary:
            AppTheme.Colors.accent
        case .secondary:
            AppTheme.Colors.borderStrong
        }
    }
}

struct AppButtonStyle: ButtonStyle {
    let variant: AppButtonVariant
    var fillsWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.bodyEmphasis)
            .foregroundStyle(variant.foreground)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: 56)
            .padding(.horizontal, fillsWidth ? 0 : AppTheme.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.large)
                    .fill(variant.background.opacity(configuration.isPressed ? 0.88 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.large)
                            .strokeBorder(variant.border, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

private extension Color {
    static func adaptive(
        light: Int,
        dark: Int,
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    UIColor(hex: dark, alpha: darkAlpha)
                } else {
                    UIColor(hex: light, alpha: lightAlpha)
                }
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: Int, alpha: Double = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
