import SwiftUI

struct OnboardingAddressView: View {
    let isActive: Bool

    @FocusState private var addressFieldFocused: Bool
    @StateObject private var locationManager = OnboardingLocationManager()
    @State private var showsText = false
    @State private var revealSequence = 0
    @State private var addressResolutionTask: Task<Void, Never>?
    @State private var focusTask: Task<Void, Never>?
    @State private var revealTask: Task<Void, Never>?
    @Binding var address: String
    @Binding var locationCoordinates: UserLocationCoordinates?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.xxLarge) {
                Spacer(minLength: 72)

                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("Your location")
                        .font(.system(size: 44, weight: .bold))
                        .tracking(-1.4)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("We use it to show stores near you.")
                        .breezeText(.body, color: AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .opacity(showsText ? 1 : 0)
                .blur(radius: showsText ? 0 : 10)
                .offset(y: showsText ? 0 : 24)

                VStack(spacing: AppTheme.Spacing.medium) {
                    Button(action: locationManager.requestCurrentLocation) {
                        HStack(spacing: AppTheme.Spacing.medium) {
                            Image(systemName: locationManager.primaryButtonSymbol)
                                .font(.system(size: 16, weight: .semibold))

                            Text(locationManager.primaryButtonTitle)
                                .breezeText(.bodyStrong)

                            Spacer()

                            if locationManager.isFetchingCurrentLocation {
                                ProgressView()
                                    .tint(AppTheme.Colors.accent)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.large)
                        .padding(.vertical, AppTheme.Spacing.large)
                    }
                    .buttonStyle(.plain)
                    .background(selectionCard(isSelected: locationManager.isResolved))

                    TextField("Enter address", text: $address)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(AppTheme.Typography.body)
                        .padding(.horizontal, AppTheme.Spacing.large)
                        .padding(.vertical, AppTheme.Spacing.large)
                        .background(selectionCard(isSelected: trimmedAddress.isEmpty == false))
                        .focused($addressFieldFocused)

                    if let statusText {
                        Text(statusText)
                            .breezeText(.meta, color: statusColor)
                            .multilineTextAlignment(.center)
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
            handleOnAppear()
            runRevealSequence()
        }
        .onChange(of: isActive, initial: false) { _, _ in
            runRevealSequence()
        }
        .onChange(of: locationManager.resolvedAddress) { _, newValue in
            guard let newValue else { return }
            addressResolutionTask?.cancel()
            address = newValue
            locationCoordinates = locationManager.resolvedCoordinates
        }
        .onChange(of: address, initial: false) { _, newValue in
            let trimmedValue = normalized(newValue)
            let resolvedAddress = normalized(locationManager.resolvedAddress)

            guard trimmedValue != resolvedAddress else {
                return
            }

            locationManager.prepareForManualAddressEntry()
            locationCoordinates = nil
            addressResolutionTask?.cancel()

            guard trimmedValue.isEmpty == false else {
                return
            }

            addressResolutionTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard Task.isCancelled == false else { return }

                let resolvedCoordinates = await locationManager.resolveTypedAddress(trimmedValue)
                guard Task.isCancelled == false else { return }

                locationCoordinates = resolvedCoordinates
            }
        }
    }

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var statusText: String? {
        if let errorMessage = locationManager.errorMessage {
            return errorMessage
        }

        if locationManager.isResolvingTypedAddress {
            return "Checking address..."
        }

        if locationManager.isResolved, let resolvedAddress = locationManager.resolvedAddress {
            return resolvedAddress
        }

        if trimmedAddress.isEmpty == false {
            return locationCoordinates == nil ? "Enter a full address to continue" : "Address verified"
        }

        return "Use your current location or enter it manually"
    }

    private var statusColor: Color {
        if locationManager.errorMessage != nil {
            return AppTheme.Colors.tertiaryText
        }

        return trimmedAddress.isEmpty ? AppTheme.Colors.tertiaryText : AppTheme.Colors.primaryText
    }

    private func handleOnAppear() {
        focusTask?.cancel()
        focusTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard Task.isCancelled == false, trimmedAddress.isEmpty else { return }
            addressFieldFocused = true
        }
    }

    private func runRevealSequence() {
        revealSequence += 1
        let sequence = revealSequence
        revealTask?.cancel()

        guard isActive else {
            showsText = false
            return
        }

        showsText = false

        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(80))
            guard Task.isCancelled == false, revealSequence == sequence, isActive else { return }

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

    private func normalized(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
