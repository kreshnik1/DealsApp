import SwiftUI

struct OnboardingBudgetView: View {
    let isActive: Bool

    @State private var showsText = false
    @State private var revealSequence = 0
    @Binding var selectedBudget: WeeklyGroceryBudget?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.xxLarge) {
                Spacer(minLength: 72)

                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("What do you spend each week?")
                        .font(.system(size: 44, weight: .bold))
                        .tracking(-1.4)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("A rough grocery estimate helps us show whether your deals are actually saving you money.")
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .opacity(showsText ? 1 : 0)
                .blur(radius: showsText ? 0 : 10)
                .offset(y: showsText ? 0 : 24)

                LazyVStack(spacing: AppTheme.Spacing.medium) {
                    ForEach(WeeklyGroceryBudget.allCases) { budget in
                        Button {
                            selectedBudget = budget
                        } label: {
                            HStack(spacing: AppTheme.Spacing.large) {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxSmall) {
                                    Text(budget.title)
                                        .breezeText(.bodyStrong)

                                    Text(budget.detail)
                                        .breezeText(.meta, color: AppTheme.Colors.secondaryText)
                                }

                                Spacer()

                                Image(systemName: selectedBudget == budget ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(
                                        selectedBudget == budget
                                        ? Color(uiColor: .systemBlue)
                                        : AppTheme.Colors.tertiaryText
                                    )
                            }
                            .padding(.horizontal, AppTheme.Spacing.large)
                            .padding(.vertical, AppTheme.Spacing.large)
                        }
                        .buttonStyle(.plain)
                        .background(selectionCard(isSelected: selectedBudget == budget))
                    }
                }
                .frame(maxWidth: 420)
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

    private func selectionCard(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
            .fill(Color(uiColor: .secondarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radii.large, style: .continuous)
                    .strokeBorder(
                        Color(uiColor: isSelected ? .systemBlue : .separator),
                        lineWidth: 1
                    )
            }
    }
}

#Preview {
    OnboardingBudgetView(
        isActive: true,
        selectedBudget: .constant(.thousandToFifteenHundred)
    )
    .breezeScreen()
}
