import SwiftUI

struct OnboardingBottomActionBar: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Button(title, action: action)
                .buttonStyle(AppButtonStyle(variant: .primary))
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.55 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, AppTheme.Spacing.medium)
        .padding(.bottom, AppTheme.Spacing.medium)
        .background {
            Rectangle()
                .fill(AppTheme.Colors.footerShade)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
