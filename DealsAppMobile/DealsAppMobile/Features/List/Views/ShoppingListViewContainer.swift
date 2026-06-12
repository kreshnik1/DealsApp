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
    @State private var isCheckedSectionExpanded = false
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
                            LazyVStack(spacing: AppTheme.Spacing.medium) {
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

                        if checkedItems.isEmpty == false {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                                Button(action: toggleCheckedSection) {
                                    HStack(spacing: AppTheme.Spacing.small) {
                                        Image(systemName: isCheckedSectionExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.Colors.secondaryText)

                                        Text("Purchased · \(checkedItems.count)")
                                            .breezeText(.bodyStrong)

                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)

                                if isCheckedSectionExpanded {
                                    LazyVStack(spacing: AppTheme.Spacing.medium) {
                                        ForEach(checkedItems) { item in
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
                                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .background(Color(uiColor: .systemBackground))
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
        activeItems.isEmpty && checkedItems.isEmpty
    }

    private var activeItems: [ShoppingListItem] {
        allItems.filter { $0.isChecked == false }
    }

    private var checkedItems: [ShoppingListItem] {
        allItems
            .filter(\.isChecked)
            .sorted {
                let lhs = $0.checkedAt ?? .distantPast
                let rhs = $1.checkedAt ?? .distantPast

                if lhs != rhs {
                    return lhs > rhs
                }

                return $0.updatedAt > $1.updatedAt
            }
    }

    private func toggleCheckedSection() {
        withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
            isCheckedSectionExpanded.toggle()
        }
    }
}
