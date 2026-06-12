import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var draftAddress = ""
    @State private var showingReplayConfirmation = false

    var body: some View {
        Form {
            Section {
                TextField("Address", text: $draftAddress, axis: .vertical)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Button("Update Address") {
                    appState.updateAddress(draftAddress)
                    draftAddress = appState.savedAddress
                }
                .disabled(trimmedAddress.isEmpty || trimmedAddress == appState.savedAddress)
            } header: {
                Text("Defaults")
            } footer: {
                Text("This value is stored locally and shown as the Breeze subtitle in the Feed.")
            }

            Section {
                Button("Replay Onboarding", role: .destructive) {
                    showingReplayConfirmation = true
                }
            } header: {
                Text("Onboarding")
            } footer: {
                Text("This returns the app to the onboarding flow so you can walk through the initial setup again.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.screenBase)
        .confirmationDialog(
            "Replay onboarding?",
            isPresented: $showingReplayConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replay Onboarding", role: .destructive) {
                appState.replayOnboarding()
                dismiss()
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This will take you back to the onboarding flow.")
        }
        .onAppear {
            if draftAddress.isEmpty {
                draftAddress = appState.savedAddress
            }
        }
    }

    private var trimmedAddress: String {
        draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState(hasCompletedOnboarding: true, savedAddress: "Malmö, Sodra Forstadsgatan 12", selectedStoreIDs: ["1", "2"]))
    }
}
