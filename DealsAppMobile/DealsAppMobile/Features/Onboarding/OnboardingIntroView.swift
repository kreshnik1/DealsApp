import SwiftUI

struct OnboardingIntroView: View {
    let isActive: Bool

    @State private var showsText = false
    @State private var revealSequence = 0

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)

                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("Welcome to Breeze")
                        .font(.system(size: 44, weight: .bold))
                        .tracking(-1.4)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Discover nearby offers, follow the stores you care about, and keep every weekly deal in one simple place.")
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .opacity(showsText ? 1 : 0)
                .blur(radius: showsText ? 0 : 10)
                .offset(y: showsText ? 0 : 28)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            runRevealSequence()
        }
        .onChange(of: isActive, initial: false) { _, _ in
            runRevealSequence()
        }
    }

    private func runRevealSequence() {
        revealSequence += 1
        let sequence = revealSequence

        guard isActive else {
            showsText = false
            return
        }

        showsText = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard revealSequence == sequence, isActive else { return }

            withAnimation(.easeOut(duration: 0.62)) {
                showsText = true
            }
        }
    }
}
