import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class CategoryManager: ObservableObject {
    @Published var categories: [CategoryModel] = []
    @Published var isLoading = false
    @Published var showProAlert = false
    
    private var categoriesListener: ListenerRegistration?
    private var isInitializing = false
    
    static let shared = CategoryManager()
    
    private init() {}
    
    func startListening(walletId: String) {
        categoriesListener?.remove()
        isLoading = true
        
        categoriesListener = Firestore.firestore().collection("wallets").document(walletId).collection("categories")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error listening categories: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    // Eğer DB boşsa ve şu an initialize edilmiyorsa mock datayı göster
                    if !self.isInitializing {
                        self.categories = CategoriesMockData.data
                    }
                    return
                }
                
                let fetched = documents.compactMap { try? $0.data(as: CategoryModel.self) }
                self.categories = fetched.sorted(by: { $0.name < $1.name })
            }
    }
    
    func stopListening() {
        categoriesListener?.remove()
        categoriesListener = nil
    }
    
    
    func checkPermission(authManager: AuthenticationManager, walletManager: WalletManager) -> Bool {
        guard let wallet = walletManager.activeWallet,
              let currentUser = authManager.currentUserProfile?.username else { return false }
        
        let roleRaw = wallet.permissions[currentUser] ?? WalletRole.member.rawValue
        let role = WalletRole(rawValue: roleRaw) ?? .member
        
        return role == .owner || role == .admin
    }
    
    func saveCategory(walletId: String, category: CategoryModel) async throws {
        // İlk kez bir değişiklik yapılıyorsa ve DB boşsa, önce varsayılanları initialize et
        if !isInitializing {
            let fetched = try await FirestoreService.shared.fetchCategories(walletId: walletId)
            if fetched.isEmpty {
                isInitializing = true
                do {
                    try await FirestoreService.shared.initializeDefaultCategories(walletId: walletId, categories: CategoriesMockData.data)
                    isInitializing = false
                } catch {
                    isInitializing = false
                    throw error
                }
            }
        }
        
        try await FirestoreService.shared.saveCategory(walletId: walletId, category: category)
    }
    
    func deleteCategory(walletId: String, category: CategoryModel) async throws {
        if !isInitializing {
            let fetched = try await FirestoreService.shared.fetchCategories(walletId: walletId)
            if fetched.isEmpty {
                isInitializing = true
                do {
                    let remaining = CategoriesMockData.data.filter { $0.id != category.id }
                    try await FirestoreService.shared.initializeDefaultCategories(walletId: walletId, categories: remaining)
                    isInitializing = false
                } catch {
                    isInitializing = false
                    throw error
                }
            } else {
                try await FirestoreService.shared.deleteCategory(walletId: walletId, categoryId: category.id)
            }
            
            // Cascade Delete: Bu kategoriye ait işlemleride sil
            try? await FirestoreService.shared.deleteTransactionsByCategory(
                walletId: walletId, 
                categoryId: category.id, 
                categoryName: category.name
            )
        }
    }
}
