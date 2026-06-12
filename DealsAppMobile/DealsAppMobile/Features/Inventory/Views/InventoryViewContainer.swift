import SwiftUI
import SwiftData

struct InventoryViewContainer: View {
    @Environment(AppState.self) private var appState

    @State private var viewModel: InventoryViewModel
    @State private var presentedErrorMessage: String?

    init(context: ModelContext) {
        _viewModel = State(initialValue: InventoryViewModel(context: context))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.section) {
                if viewModel.items.isEmpty {
                    InventoryEmptyStateView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 72)
                } else {
                    HStack {
                        Text("\(viewModel.itemCount) item\(viewModel.itemCount == 1 ? "" : "s") in stock")
                            .breezeText(.meta, color: AppTheme.Colors.secondaryText)

                        Spacer(minLength: 0)
                    }

                    LazyVStack(spacing: AppTheme.Spacing.medium) {
                        ForEach(viewModel.items) { item in
                            InventoryRowView(
                                item: item,
                                onFinish: {
                                    withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                        viewModel.completeItem(item, using: .finished)
                                    }
                                },
                                onWaste: {
                                    withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                        viewModel.completeItem(item, using: .wasted)
                                    }
                                },
                                onFinishAndAddBack: {
                                    withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                        viewModel.completeAndAddBack(item, using: .finished)
                                    }
                                },
                                onWasteAndAddBack: {
                                    withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                        viewModel.completeAndAddBack(item, using: .wasted)
                                    }
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentMargins(.top, AppTheme.Spacing.xLarge, for: .scrollContent)
        .contentMargins(.horizontal, AppTheme.Spacing.screenInset, for: .scrollContent)
        .contentMargins(.bottom, AppTheme.Spacing.xxLarge, for: .scrollContent)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            if let bannerState = viewModel.bannerState {
                InventoryBannerView(
                    state: bannerState,
                    onPrimaryAction: {
                        withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                            viewModel.handleBannerPrimaryAction()
                        }
                    },
                    onUndo: {
                        withAnimation(.snappy(duration: 0.22, extraBounce: 0)) {
                            viewModel.undoBannerAction()
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.22, extraBounce: 0), value: viewModel.bannerState?.id)
        .navigationTitle("Inventory")
        .navigationSubtitle(appState.savedAddress)
        .navigationBarTitleDisplayMode(.large)
        .toolbarTitleDisplayMode(.large)
        .task {
            viewModel.load()
        }
        .task(id: viewModel.bannerState?.id) {
            guard let bannerState = viewModel.bannerState else {
                return
            }

            try? await Task.sleep(for: .seconds(4))

            guard viewModel.bannerState?.id == bannerState.id else {
                return
            }

            viewModel.dismissBanner()
        }
        .refreshable {
            viewModel.load()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            presentedErrorMessage = newValue
        }
        .alert(
            "Inventory",
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
}
