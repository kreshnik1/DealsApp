import SwiftUI

struct ShoppingListComposerView: View {
    @Binding var draftName: String
    @Binding var draftQuantityText: String

    let onSubmit: () -> Void

    @FocusState private var isNameFocused: Bool

    private var isSubmitDisabled: Bool {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsQuantityField: Bool {
        isNameFocused || draftQuantityText.isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.accentStrong)
                    .frame(width: 38, height: 38)
                    .breezeSurface(
                        fill: AppTheme.Colors.accentSoft2,
                        border: AppTheme.Colors.activeBorder,
                        radius: AppTheme.Radii.phone
                    )

                TextField("Add milk, pasta, fruit...", text: $draftName)
                    .breezeText(.body)
                    .focused($isNameFocused)
                    .submitLabel(.send)
                    .onSubmit(handleSubmit)

                Button(action: handleSubmit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            isSubmitDisabled
                                ? AppTheme.Colors.tertiaryText
                                : AppTheme.Colors.buttonPrimaryText
                        )
                        .frame(width: 42, height: 42)
                        .background(submitBackground)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitDisabled)
                .accessibilityLabel("Add item")
            }

            if showsQuantityField {
                TextField("Quantity or pack size", text: $draftQuantityText)
                    .breezeText(.body)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .breezeSurface(
                        fill: AppTheme.Colors.textFieldFill,
                        border: AppTheme.Colors.borderStrong,
                        radius: AppTheme.Radii.medium
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .breezeGlassPanel(.panel, cornerRadius: 30)
        .animation(.snappy(duration: 0.22, extraBounce: 0), value: showsQuantityField)
    }

    private var submitBackground: some View {
        Circle()
            .fill(isSubmitDisabled ? AppTheme.Colors.panelFillStrong : AppTheme.Colors.accent)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSubmitDisabled ? AppTheme.Colors.borderStrong : AppTheme.Colors.accent,
                        lineWidth: 1
                    )
            )
    }

    private func handleSubmit() {
        let originalDraft = draftName
        onSubmit()

        if originalDraft != draftName {
            isNameFocused = true
        }
    }
}
