import SwiftUI

struct OnboardingAddressView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var addressFieldFocused: Bool
    @State private var address = ""

    let onBack: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                }
                .frame(width: 44, height: 44)
                .breezeSurface(
                    fill: AppTheme.Colors.panelFillStrong,
                    border: AppTheme.Colors.borderStrong,
                    radius: AppTheme.Radii.phone
                )

                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    Text("STARTING POINT")
                        .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

                    Text("Set the address you want Breeze to open with.")
                        .breezeText(.hero)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("For now this exact address appears beneath the Breeze title in the Feed. Later it becomes the basis for nearby stores and personalization.")
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                        Text("Address")
                            .breezeText(.eyebrow, color: AppTheme.Colors.accentStrong)

                        TextField("Malmö, Sodra Forstadsgatan 12", text: $address)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(AppTheme.Typography.body)
                            .padding(.horizontal, AppTheme.Spacing.large)
                            .padding(.vertical, AppTheme.Spacing.large)
                            .breezeSurface(
                                fill: AppTheme.Colors.textFieldFill,
                                border: AppTheme.Colors.border,
                                radius: AppTheme.Radii.large
                            )
                            .focused($addressFieldFocused)

                        Text("You can change this later from Settings.")
                            .breezeText(.meta, color: AppTheme.Colors.tertiaryText)
                    }

                    OnboardingAddressPreviewCard(address: previewAddress)
                }
                .padding(20)
                .breezeSurface(
                    fill: AppTheme.Colors.panelFill,
                    border: AppTheme.Colors.border,
                    radius: AppTheme.Radii.xLarge
                )

                Spacer(minLength: AppTheme.Spacing.xxLarge)
            }
            .padding(.horizontal, AppTheme.Spacing.screenInset)
            .padding(.top, AppTheme.Spacing.xxLarge)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            OnboardingBottomActionBar(
                title: "Enter Breeze",
                isDisabled: trimmedAddress.isEmpty,
                action: completeOnboarding
            )
        }
        .onAppear(perform: handleOnAppear)
    }

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewAddress: String {
        trimmedAddress.isEmpty ? "Your saved address will appear here." : trimmedAddress
    }

    private func completeOnboarding() {
        appState.completeOnboarding(with: address)
    }

    private func handleOnAppear() {
        if address.isEmpty {
            address = appState.savedAddress
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            addressFieldFocused = true
        }
    }
}
