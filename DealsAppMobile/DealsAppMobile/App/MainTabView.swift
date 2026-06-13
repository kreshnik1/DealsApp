import SwiftUI

private enum AppTab: Hashable {
    case home
    case list
    case inventory
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

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
