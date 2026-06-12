import SwiftData
import SwiftUI

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        InventoryViewContainer(context: modelContext)
    }
}

#Preview {
    NavigationStack {
        InventoryView()
            .environment(AppState(
                hasCompletedOnboarding: true,
                savedAddress: "Malmö, Södra Förstadsgatan 12",
                selectedStoreIDs: ["1", "2"]
            ))
    }
    .modelContainer(AppPreviewContainer.shoppingList)
}
