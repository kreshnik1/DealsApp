import SwiftUI

private enum AppTab: Hashable {
    case feed
    case stores
    case list
    case inventory
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .feed

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView()
            }
            .tabItem {
                Label("Feed", systemImage: "square.grid.2x2.fill")
            }
            .tag(AppTab.feed)

            NavigationStack {
                StoresView()
            }
            .tabItem {
                Label("Stores", systemImage: "building.2.fill")
            }
            .tag(AppTab.stores)

            NavigationStack {
                ShoppingListView()
            }
            .tabItem {
                Label("List", systemImage: "checklist")
            }
            .tag(AppTab.list)

            NavigationStack {
                InventoryView()
            }
            .tabItem {
                Label("Inventory", systemImage: "shippingbox.fill")
            }
            .tag(AppTab.inventory)
        }
    }
}
