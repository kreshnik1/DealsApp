import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ShoppingListViewModel {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let now: () -> Date

    var draftName: String
    var draftQuantityText: String

    private(set) var activeItems: [ShoppingListItem]
    private(set) var checkedItems: [ShoppingListItem]
    private(set) var isLoading: Bool
    private(set) var errorMessage: String?
    private(set) var completionFeedbackTrigger: Int

    init(
        context: ModelContext,
        now: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.now = now
        self.draftName = ""
        self.draftQuantityText = ""
        self.activeItems = []
        self.checkedItems = []
        self.isLoading = false
        self.errorMessage = nil
        self.completionFeedbackTrigger = 0
    }

    var isSubmitDisabled: Bool {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeItemCount: Int {
        activeItems.count
    }

    var checkedItemCount: Int {
        checkedItems.count
    }

    var linkedItemCount: Int {
        (activeItems + checkedItems).filter(\.hasLinkedProduct).count
    }

    var preferredStoreCount: Int {
        Set((activeItems + checkedItems).compactMap(\.preferredStoreID)).count
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            try reloadData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItemFromDraft() {
        guard isSubmitDisabled == false else {
            return
        }

        do {
            try mutations.createItem(
                name: draftName,
                quantityText: draftQuantityText,
                now: now()
            )
            draftName = ""
            draftQuantityText = ""
            try reloadData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleChecked(for item: ShoppingListItem) {
        do {
            try mutations.setChecked(item, to: !item.isChecked, now: now())
            if item.isChecked {
                completionFeedbackTrigger += 1
            }
            try reloadData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: ShoppingListItem) {
        do {
            try mutations.deleteItem(item)
            try reloadData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveEdits(
        for item: ShoppingListItem,
        name: String,
        quantityText: String,
        notes: String
    ) {
        do {
            try mutations.updateItem(
                item,
                name: name,
                quantityText: quantityText,
                notes: notes,
                imageURL: item.imageURL,
                priceSnapshot: item.priceSnapshot,
                originalPriceSnapshot: item.originalPriceSnapshot,
                comparisonPriceSnapshot: item.comparisonPriceSnapshot,
                productID: item.productID,
                preferredStoreID: item.preferredStoreID,
                preferredStoreName: item.preferredStoreName,
                now: now()
            )
            try reloadData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private var queries: ShoppingListQueryService {
        ShoppingListQueryService(context: context)
    }

    private var mutations: ShoppingListMutationService {
        ShoppingListMutationService(context: context)
    }

    private func reloadData() throws {
        activeItems = try queries.activeItems()
        checkedItems = try queries.checkedItems()
    }
}
