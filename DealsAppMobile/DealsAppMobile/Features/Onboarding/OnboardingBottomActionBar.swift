import SwiftUI
import UIKit

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
        GlassEffectContainer(spacing: 20) {
            VStack(spacing: AppTheme.Spacing.medium) {
                Button(title, action: handleTap)
                    .buttonStyle(.glassProminent)
                    .disabled(isDisabled)
                    .opacity(isDisabled ? 0.55 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, AppTheme.Spacing.medium)
        .padding(.bottom, AppTheme.Spacing.medium)
        .background(.clear)
    }

    private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.85)
        action()
    }
}
