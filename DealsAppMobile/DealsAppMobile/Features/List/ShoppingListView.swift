import SwiftData
import SwiftUI

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ShoppingListViewContainer(context: modelContext)
    }
}

#Preview {
    NavigationStack {
        ShoppingListView()
            .environment(AppState(
                hasCompletedOnboarding: true,
                savedAddress: "Malmö, Södra Förstadsgatan 12",
                selectedStoreIDs: ["1", "2"]
            ))
    }
    .modelContainer(AppPreviewContainer.shoppingList)
}
