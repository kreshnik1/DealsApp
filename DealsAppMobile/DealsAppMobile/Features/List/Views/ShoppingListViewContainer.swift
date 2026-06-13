import SwiftUI
import SwiftData

struct ShoppingListViewContainer: View {
    @Environment(AppState.self) private var appState

    @Query(
        sort: [
            SortDescriptor(\ShoppingListItem.sortOrder),
            SortDescriptor(\ShoppingListItem.createdAt),
        ]
    ) private var allItems: [ShoppingListItem]

    @State private var viewModel: ShoppingListViewModel
    @State private var editingItem: ShoppingListItem?
    @State private var presentedErrorMessage: String?

    init(context: ModelContext) {
        _viewModel = State(initialValue: ShoppingListViewModel(context: context))
    }

    var body: some View {
        Group {
            if showsEmptyState {
                ShoppingListEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, AppTheme.Spacing.screenInset)
                    .padding(.bottom, 92)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                        if activeItems.isEmpty == false {
                            LazyVStack(spacing: AppTheme.Spacing.small) {
                                ForEach(activeItems) { item in
                                    ShoppingListRowView(
                                        item: item,
                                        onToggleChecked: {
                                            withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                                viewModel.toggleChecked(for: item)
                                            }
                                        },
                                        onEdit: {
                                            editingItem = item
                                        },
                                        onDelete: {
                                            withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                                viewModel.deleteItem(item)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.screenInset)
                    .padding(.top, AppTheme.Spacing.xLarge)
                    .padding(.bottom, 140)
                }
            }
        }
        .breezeMainAppScreen()
        .navigationTitle("Shopping List")
        .navigationSubtitle(appState.savedAddress)
        .navigationBarTitleDisplayMode(.large)
        .toolbarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            ShoppingListComposerView(
                draftName: $viewModel.draftName,
                draftQuantityText: $viewModel.draftQuantityText,
                onSubmit: viewModel.addItemFromDraft
            )
            .padding(.horizontal, 14)
            .padding(.bottom, AppTheme.Spacing.small)
        }
        .sheet(item: $editingItem) { item in
            ShoppingListEditSheetView(
                item: item,
                onSave: { name, quantityText, notes in
                    viewModel.saveEdits(
                        for: item,
                        name: name,
                        quantityText: quantityText,
                        notes: notes
                    )
                    editingItem = nil
                },
                onCancel: {
                    editingItem = nil
                }
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            viewModel.load()
        }
        .onAppear {
            viewModel.load()
        }
        .refreshable {
            viewModel.load()
        }
        .sensoryFeedback(.success, trigger: viewModel.completionFeedbackTrigger)
        .onChange(of: viewModel.errorMessage) { _, newValue in
            presentedErrorMessage = newValue
        }
        .alert(
            "Shopping List",
            isPresented: isShowingError,
            presenting: presentedErrorMessage
        ) { _ in
            Button("OK", role: .cancel) {
                presentedErrorMessage = nil
                viewModel.clearError()
            }
        } message: { message in
            Text(message)
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { presentedErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    presentedErrorMessage = nil
                    viewModel.clearError()
                }
            }
        )
    }

    private var showsEmptyState: Bool {
        activeItems.isEmpty
    }

    private var activeItems: [ShoppingListItem] {
        allItems.filter { $0.isChecked == false }
    }
}
