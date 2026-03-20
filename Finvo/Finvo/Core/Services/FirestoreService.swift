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
            }
    }
    
    func stopListeningWallets() {
        walletsListener?.remove()
        walletsListener = nil
        wallets = []
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
}
