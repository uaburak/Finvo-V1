import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class FamilyShoppingViewModel: ObservableObject {
    @Published var items: [ShoppingItemModel] = []
    @Published var isLoading: Bool = false
    
    // Geçici olarak Firebase yerine RAM'de tutalım (V1 için hızlı prototipleme)
    // Eğer Firestore koleksiyonu hazırsa buradaki mantık `.addDocument` ile değiştirilebilir.
    
    func fetchItems(for walletId: String) {
        // Örnek mock veriler
        if items.isEmpty {
            items = [
                ShoppingItemModel(walletId: walletId, title: "Market Alışverişi (Süt, Yumurta)", estimatedAmount: 450.0, addedBy: "Özge"),
                ShoppingItemModel(walletId: walletId, title: "Netflix Yenilemesi", estimatedAmount: 150.0, addedBy: "Burak")
            ]
        }
    }
    
    func addItem(title: String, amount: Double?, walletId: String, username: String) {
        let newItem = ShoppingItemModel(
            walletId: walletId,
            title: title,
            estimatedAmount: amount,
            isPurchased: false,
            addedBy: username
        )
        // Normalde: db.collection("wallets").document(walletId).collection("shoppingList").addDocument(...)
        items.insert(newItem, at: 0)
    }
    
    func toggleItem(_ item: ShoppingItemModel) {
        if let index = items.firstIndex(where: { $0.id == item.id || $0.title == item.title }) {
            items[index].isPurchased.toggle()
        }
    }
    
    func deleteItem(_ item: ShoppingItemModel) {
        items.removeAll(where: { $0.id == item.id || $0.title == item.title })
    }
}
