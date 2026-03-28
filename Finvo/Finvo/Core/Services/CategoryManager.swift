import Foundation
import SwiftUI
import Combine

@MainActor
class CategoryManager: ObservableObject {
    @Published var categories: [CategoryModel] = []
    @Published var isLoading = false
    @Published var showProAlert = false
    private var isInitializing = false // Race condition önleyici
    
    static let shared = CategoryManager()
    
    private init() {}
    
    func loadCategories(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await FirestoreService.shared.fetchCategories(uid: uid)
            if fetched.isEmpty {
                // Eğer DB boşsa ve şu an initialize edilmiyorsa mock datayı göster
                if !isInitializing {
                    self.categories = CategoriesMockData.data
                }
            } else {
                // DB'den gelenleri isimlerine göre sırala
                self.categories = fetched.sorted(by: { $0.name < $1.name })
            }
        } catch {
            print("Kategoriler yüklenirken hata: \(error)")
            if !isInitializing {
                self.categories = CategoriesMockData.data
            }
        }
    }
    
    func checkProAndExecute(authManager: AuthenticationManager, action: @escaping () -> Void) {
        if authManager.currentUserProfile?.isPro == true {
            action()
        } else {
            showProAlert = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
    
    func saveCategory(uid: String, category: CategoryModel) async throws {
        // İlk kez bir değişiklik yapılıyorsa ve DB boşsa, önce varsayılanları initialize et
        if !isInitializing {
            let fetched = try await FirestoreService.shared.fetchCategories(uid: uid)
            if fetched.isEmpty {
                isInitializing = true
                do {
                    try await FirestoreService.shared.initializeDefaultCategories(uid: uid, categories: CategoriesMockData.data)
                    isInitializing = false
                } catch {
                    isInitializing = false
                    throw error
                }
            }
        }
        
        try await FirestoreService.shared.saveCategory(uid: uid, category: category)
        await loadCategories(uid: uid)
    }
    
    func deleteCategory(uid: String, walletId: String?, category: CategoryModel) async throws {
        if !isInitializing {
            let fetched = try await FirestoreService.shared.fetchCategories(uid: uid)
            if fetched.isEmpty {
                isInitializing = true
                do {
                    let remaining = CategoriesMockData.data.filter { $0.id != category.id }
                    try await FirestoreService.shared.initializeDefaultCategories(uid: uid, categories: remaining)
                    isInitializing = false
                } catch {
                    isInitializing = false
                    throw error
                }
            } else {
                try await FirestoreService.shared.deleteCategory(uid: uid, categoryId: category.id)
            }
            
            // Cascade Delete: Bu kategoriye ait işlemleride sil
            if let wId = walletId {
                try? await FirestoreService.shared.deleteTransactionsByCategory(
                    walletId: wId, 
                    categoryId: category.id, 
                    categoryName: category.name
                )
            }
        }
        await loadCategories(uid: uid)
    }
}
