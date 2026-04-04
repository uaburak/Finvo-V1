import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

class FirestoreService: ObservableObject {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    @Published var wallets: [WalletModel] = []
    private var walletsListener: ListenerRegistration?
    
    private init() {}
    
    // MARK: - Wallet Operations
    func createWallet(_ wallet: WalletModel) async throws {
        let docRef = db.collection("wallets").document()
        try docRef.setData(from: wallet)
    }
    
    func startListeningWallets(forUser identifier: String) {
        if walletsListener != nil { return }
        
        walletsListener = db.collection("wallets")
            .whereField("members", arrayContains: identifier)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    self.wallets = []
                    return
                }
                
                self.wallets = documents.compactMap { try? $0.data(as: WalletModel.self) }
                    .filter { $0.permissions[identifier] != WalletRole.pending.rawValue }
            }
    }
    
    func stopListeningWallets() {
        walletsListener?.remove()
        walletsListener = nil
    }
    
    func updateWallet(_ wallet: WalletModel) async throws {
        guard let id = wallet.id else { return }
        try db.collection("wallets").document(id).setData(from: wallet, merge: true)
    }
    
    func deleteWallet(id: String) async throws {
        try await db.collection("wallets").document(id).delete()
    }
    
    // MARK: - Member Operations
    func addMember(walletId: String, userId: String, role: WalletRole) async throws {
        try await db.collection("wallets").document(walletId).updateData([
            "members": FieldValue.arrayUnion([userId]),
            "permissions.\(userId)": role.rawValue
        ])
    }
    
    func removeMember(walletId: String, userId: String) async throws {
        try await db.collection("wallets").document(walletId).updateData([
            "members": FieldValue.arrayRemove([userId]),
            "permissions.\(userId)": FieldValue.delete()
        ])
    }
    
    // MARK: - User Profile Operations
    func isUsernameTaken(_ username: String) async throws -> Bool {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .getDocuments()
        return !snapshot.isEmpty
    }
    
    func saveUserProfile(_ userProfile: UserModel) async throws {
        try db.collection("users").document(userProfile.uid).setData(from: userProfile)
    }
    
    func updateUserPhoto(uid: String, url: String) async throws {
        try await db.collection("users").document(uid).updateData(["photoUrl": url])
    }
    
    func getUserProfile(uid: String) async throws -> UserModel? {
        let doc = try await db.collection("users").document(uid).getDocument()
        return try? doc.data(as: UserModel.self)
    }
    
    func getUserProfileByUsername(_ username: String) async throws -> UserModel? {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .limit(to: 1)
            .getDocuments()
        return try? snapshot.documents.first?.data(as: UserModel.self)
    }
    
    func getUserProfileByEmail(_ email: String) async throws -> UserModel? {
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email.lowercased())
            .limit(to: 1)
            .getDocuments()
        return try? snapshot.documents.first?.data(as: UserModel.self)
    }
    
    // MARK: - Notification Operations
    func sendNotification(_ notification: NotificationModel) async throws {
        let docRef = db.collection("notifications").document()
        try docRef.setData(from: notification)
    }
    
    func updateNotificationStatus(id: String, status: NotificationStatus) async throws {
        try await db.collection("notifications").document(id).updateData([
            "status": status.rawValue
        ])
    }
    
    // Listen for Notifications will be handled via native Snapshotlistener in Manager
    
    func searchUsers(query: String) async throws -> [UserModel] {
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
            .whereField("username", isLessThanOrEqualTo: query.lowercased() + "\u{f8ff}")
            .limit(to: 5)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: UserModel.self) }
    }
    
    // MARK: - Transaction Operations
    func createTransaction(_ transaction: TransactionModel) throws {
        let docRef = db.collection("wallets").document(transaction.walletId).collection("transactions").document()
        try docRef.setData(from: transaction)
    }
    
    func updateTransaction(_ transaction: TransactionModel) throws {
        guard let id = transaction.id else { return }
        try db.collection("wallets").document(transaction.walletId).collection("transactions").document(id).setData(from: transaction, merge: true)
    }
    
    func deleteTransaction(walletId: String, transactionId: String) {
        db.collection("wallets").document(walletId).collection("transactions").document(transactionId).delete()
    }
    
    func deleteTransactionsByCategory(walletId: String, categoryId: String, categoryName: String) async throws {
        let transactions = db.collection("wallets").document(walletId).collection("transactions")
        
        // Hem ID hem de isim ile kontrol et (Geriye dönük uyumluluk için)
        // Önce ID ile olanları bul
        let snapshotById = try await transactions.whereField("mainCategoryId", isEqualTo: categoryId).getDocuments()
        
        // Sonra İsim ile olanları bul (ID'si olmayan eski kayıtlar için)
        let snapshotByName = try await transactions.whereField("mainCategoryName", isEqualTo: categoryName).getDocuments()
        
        let batch = db.batch()
        
        for doc in snapshotById.documents {
            batch.deleteDocument(doc.reference)
        }
        
        for doc in snapshotByName.documents {
            // Zaten eklenmişse tekrar ekleme (Opsiyonel ama temizlik için)
            if !snapshotById.documents.contains(where: { $0.documentID == doc.documentID }) {
                batch.deleteDocument(doc.reference)
            }
        }
        
        try await batch.commit()
    }
    
    func deleteTransactionsBySubCategory(walletId: String, mainCategoryId: String, subCategoryId: String, subCategoryName: String) async throws {
        let transactions = db.collection("wallets").document(walletId).collection("transactions")
        
        // ID ile bul
        let snapshotById = try await transactions
            .whereField("mainCategoryId", isEqualTo: mainCategoryId)
            .whereField("subCategoryId", isEqualTo: subCategoryId)
            .getDocuments()
        
        // İsim ile bul (ID'si olmayan eski kayıtlar için)
        // Not: subCategoryName tek başına güvenli olmayabilir, mainCategoryName ile birleştirmek daha iyi
        let snapshotByName = try await transactions
            .whereField("subCategoryName", isEqualTo: subCategoryName)
            .getDocuments()
        
        let batch = db.batch()
        for doc in snapshotById.documents { batch.deleteDocument(doc.reference) }
        for doc in snapshotByName.documents {
            // Sadece doğru ana kategoriye ait olanları sil (Eski kayıtlar için isim bazlı kontrol)
            // Bu kısım biraz riskli olsa da kullanıcının isteği yönünde cascade delete sağlar.
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }
    
    // MARK: - Category Operations
    func fetchCategories(walletId: String) async throws -> [CategoryModel] {
        let snapshot = try await db.collection("wallets").document(walletId).collection("categories").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CategoryModel.self) }
    }
    
    func saveCategory(walletId: String, category: CategoryModel) async throws {
        let docRef: DocumentReference
        if let fid = category.firestoreId {
            docRef = db.collection("wallets").document(walletId).collection("categories").document(fid)
        } else {
            // Eğer ID henüz yoksa (mock data), deterministik safeId kullan
            docRef = db.collection("wallets").document(walletId).collection("categories").document(category.safeId)
        }
        try docRef.setData(from: category, merge: true)
    }
    
    func deleteCategory(walletId: String, categoryId: String) async throws {
        try await db.collection("wallets").document(walletId).collection("categories").document(categoryId).delete()
    }
    
    func deleteAllCategories(walletId: String) async throws {
        let snapshot = try await db.collection("wallets").document(walletId).collection("categories").getDocuments()
        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }
    
    func initializeDefaultCategories(walletId: String, categories: [CategoryModel]) async throws {
        let batch = db.batch()
        for category in categories {
            // İsim bazlı deterministik ID kullanımı (Duplicate önlemek için)
            let docRef = db.collection("wallets").document(walletId).collection("categories").document(category.safeId)
            try batch.setData(from: category, forDocument: docRef)
        }
        try await batch.commit()
    }
}
