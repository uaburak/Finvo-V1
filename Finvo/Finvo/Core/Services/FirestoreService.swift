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
                // Geçici bir ağ/izin hatasında listeyi boşaltmıyoruz; aksi halde aktif cüzdan
                // nil olup tüm dinleyiciler kapanıyor ve tekrar açılınca her şey baştan okunuyordu.
                if let error = error {
                    print("Error listening wallets: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                
                self.wallets = documents.compactMap { try? $0.data(as: WalletModel.self) }
                    .filter { $0.permissions[identifier] != WalletRole.pending.rawValue }
            }
    }
    
    func stopListeningWallets() {
        walletsListener?.remove()
        walletsListener = nil
        // Çıkış yapıldığında önceki kullanıcının cüzdanları bellekte kalmasın
        // (yeni hesapla girişte kısa süreliğine eski cüzdanlar görünüyordu).
        if !wallets.isEmpty { wallets = [] }
    }
    
    func updateWallet(_ wallet: WalletModel) async throws {
        guard let id = wallet.id else { return }
        try db.collection("wallets").document(id).setData(from: wallet, merge: true)
    }
    
    /// Cüzdanı alt koleksiyonlarıyla birlikte siler. Firestore'da doküman silmek alt koleksiyonları
    /// silmez; eskiden işlemler/kategoriler sahipsiz kalıp depolama kotasını boşuna dolduruyordu.
    func deleteWallet(id: String) async throws {
        let walletRef = db.collection("wallets").document(id)
        for subcollection in Self.walletSubcollections {
            try await deleteAllDocuments(in: walletRef.collection(subcollection))
        }
        try await walletRef.delete()
    }

    static let walletSubcollections = ["transactions", "categories", "shoppingList", "missions"]

    /// Bir koleksiyondaki tüm dokümanları 400'lük parçalar halinde siler (batch limiti 500).
    func deleteAllDocuments(in collection: CollectionReference) async throws {
        while true {
            let snapshot = try await collection.limit(to: 400).getDocuments()
            guard !snapshot.documents.isEmpty else { return }
            try await deleteDocuments(snapshot.documents.map(\.reference))
            if snapshot.documents.count < 400 { return }
        }
    }

    /// Referansları 400'lük batch'ler halinde siler. Tek bir batch 500 işlemden fazlasını kabul etmez.
    func deleteDocuments(_ references: [DocumentReference]) async throws {
        var start = 0
        while start < references.count {
            let end = min(start + 400, references.count)
            let batch = db.batch()
            for ref in references[start..<end] { batch.deleteDocument(ref) }
            try await batch.commit()
            start = end
        }
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
        let snapshotById = try await transactions.whereField("mainCategoryId", isEqualTo: categoryId).getDocuments()
        let snapshotByName = try await transactions.whereField("mainCategoryName", isEqualTo: categoryName).getDocuments()
        
        var refs: [String: DocumentReference] = [:]
        for doc in snapshotById.documents { refs[doc.documentID] = doc.reference }
        for doc in snapshotByName.documents {
            // İsim eşleşmesi sadece ID'si olmayan (eski) kayıtlar ya da aynı ID'li kayıtlar için geçerli;
            // aynı isimli ama farklı ID'li başka bir kategorinin işlemleri silinmemeli.
            let docCategoryId = doc.data()["mainCategoryId"] as? String
            if docCategoryId == nil || docCategoryId == categoryId {
                refs[doc.documentID] = doc.reference
            }
        }
        
        try await deleteDocuments(Array(refs.values))
    }
    
    func deleteTransactionsBySubCategory(walletId: String, mainCategoryId: String, mainCategoryName: String? = nil, subCategoryId: String, subCategoryName: String) async throws {
        let transactions = db.collection("wallets").document(walletId).collection("transactions")
        
        // ID ile bul
        let snapshotById = try await transactions
            .whereField("mainCategoryId", isEqualTo: mainCategoryId)
            .whereField("subCategoryId", isEqualTo: subCategoryId)
            .getDocuments()
        
        // İsim ile bul (ID'si olmayan eski kayıtlar için)
        let snapshotByName = try await transactions
            .whereField("subCategoryName", isEqualTo: subCategoryName)
            .getDocuments()
        
        var refs: [String: DocumentReference] = [:]
        for doc in snapshotById.documents { refs[doc.documentID] = doc.reference }
        for doc in snapshotByName.documents {
            // Eskiden aynı isimli alt kategoriye sahip TÜM ana kategorilerin işlemleri siliniyordu
            // (ör. "Diğer"). Sadece bu ana kategoriye ait olanları sil.
            let data = doc.data()
            let docMainId = data["mainCategoryId"] as? String
            let docMainName = data["mainCategoryName"] as? String
            let docSubId = data["subCategoryId"] as? String
            let belongsToMain = docMainId == mainCategoryId || (docMainId == nil && mainCategoryName != nil && docMainName == mainCategoryName)
            let subMatches = docSubId == nil || docSubId == subCategoryId
            if belongsToMain && subMatches {
                refs[doc.documentID] = doc.reference
            }
        }
        try await deleteDocuments(Array(refs.values))
    }
    
    // MARK: - Category Operations
    func fetchCategories(walletId: String) async throws -> [CategoryModel] {
        let snapshot = try await db.collection("wallets").document(walletId).collection("categories").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CategoryModel.self) }
    }
    
    func hasAnyCategory(walletId: String) async throws -> Bool {
        let snapshot = try await db.collection("wallets").document(walletId).collection("categories").limit(to: 1).getDocuments()
        return !snapshot.isEmpty
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
        try await deleteAllDocuments(in: db.collection("wallets").document(walletId).collection("categories"))
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
