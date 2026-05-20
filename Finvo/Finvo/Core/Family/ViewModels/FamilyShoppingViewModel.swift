import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class FamilyShoppingViewModel: ObservableObject {
    @Published var items: [ShoppingItemModel] = []
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentWalletId: String?

    // MARK: - Computed
    var pendingItemsCount: Int { items.filter { !$0.isPurchased }.count }
    var totalEstimatedAmount: Double {
        items.filter { !$0.isPurchased }.compactMap(\.estimatedAmount).reduce(0, +)
    }

    // MARK: - Fetch (Real-time)
    func fetchItems(for walletId: String) {
        guard walletId != currentWalletId else { return }
        currentWalletId = walletId
        listener?.remove()
        isLoading = true

        listener = db.collection("wallets")
            .document(walletId)
            .collection("shoppingList")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error { print("🛒 Shopping fetch error: \(error)"); return }
                self.items = snapshot?.documents.compactMap {
                    try? $0.data(as: ShoppingItemModel.self)
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        currentWalletId = nil
    }

    // MARK: - Write Operations
    func addItem(title: String, amount: Double?, walletId: String, username: String) {
        let newItem = ShoppingItemModel(
            walletId: walletId,
            title: title,
            estimatedAmount: amount,
            isPurchased: false,
            addedBy: username
        )
        // Fix: try? sonuçsuz bırakılmıştı, Task içinde hata logluyoruz
        Task {
            do {
                try db.collection("wallets")
                    .document(walletId)
                    .collection("shoppingList")
                    .addDocument(from: newItem)
            } catch {
                print("🛒 Shopping item ekleme hatası: \(error)")
            }
        }
    }

    func toggleItem(_ item: ShoppingItemModel) {
        guard let id = item.id, let walletId = currentWalletId else { return }
        db.collection("wallets")
            .document(walletId)
            .collection("shoppingList")
            .document(id)
            .updateData(["isPurchased": !item.isPurchased])
    }

    func deleteItem(_ item: ShoppingItemModel) {
        guard let id = item.id, let walletId = currentWalletId else { return }
        db.collection("wallets")
            .document(walletId)
            .collection("shoppingList")
            .document(id)
            .delete()
    }
}
