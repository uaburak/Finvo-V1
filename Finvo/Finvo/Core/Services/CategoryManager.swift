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
                // DB'den gelenleri isim bazlı tekilleştir (Ghost dökümanlardan kurtulmak için)
                var uniqueDict: [String: CategoryModel] = [:]
                for cat in fetched {
                    let key = cat.name.lowercased().trimmingCharacters(in: .whitespaces)
                    if uniqueDict[key] == nil || cat.firestoreId == cat.safeId {
                        uniqueDict[key] = cat
                    }
                }
                self.categories = Array(uniqueDict.values).sorted(by: { $0.name < $1.name })
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
    
    func deleteCategory(uid: String, categoryId: String) async throws {
        if !isInitializing {
            let fetched = try await FirestoreService.shared.fetchCategories(uid: uid)
            if fetched.isEmpty {
                isInitializing = true
                do {
                    let remaining = CategoriesMockData.data.filter { $0.id != categoryId }
                    try await FirestoreService.shared.initializeDefaultCategories(uid: uid, categories: remaining)
                    isInitializing = false
                } catch {
                    isInitializing = false
                    throw error
                }
            } else {
                try await FirestoreService.shared.deleteCategory(uid: uid, categoryId: categoryId)
            }
        }
        await loadCategories(uid: uid)
    }
}
