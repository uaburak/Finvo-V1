import Foundation
import FirebaseCore
import Combine
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated: Bool = false
    @Published var isProfileComplete: Bool = false
    @Published var isProfileLoading: Bool = false
    @Published var currentUserProfile: UserModel?
    @Published var authError: String?
    
    // Apple Sign-In için Güvenlik Kodu (Nonce)
    var currentNonce: String?
    
    static let shared = AuthenticationManager()
    
    private init() {
        self.user = Auth.auth().currentUser
        self.isAuthenticated = self.user != nil
        
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = user != nil
            
            
            if user != nil {
                self.isProfileLoading = true
                Task {
                    await self.checkUserProfile()
                }
            } else {
                self.isProfileComplete = false
                self.currentUserProfile = nil
            }
        }
    }
    
    func checkUserProfile() async {
        guard let uid = user?.uid else {
            await MainActor.run {
                self.isProfileLoading = false
                self.isProfileComplete = false
                self.currentUserProfile = nil
            }
            return
        }
        
        await MainActor.run {
            self.isProfileLoading = true
        }
        
        if let profile = try? await FirestoreService.shared.getUserProfile(uid: uid) {
            await MainActor.run {
                self.currentUserProfile = profile
                self.isProfileComplete = !profile.username.isEmpty
                self.authError = nil
            }
            
            // Eğer Firebase profil resmi var ama uygulamada yoksa (Apple ile girip resmi alamayıp sonra Google ile girme durumu)
            if profile.photoUrl == nil, let photoURL = user?.photoURL?.absoluteString {
                try? await FirestoreService.shared.updateUserPhoto(uid: uid, url: photoURL)
                await MainActor.run {
                    self.currentUserProfile?.photoUrl = photoURL
                }
            }
            
            await MainActor.run {
                self.isProfileLoading = false
            }
        } else if let email = user?.email, let _ = try? await FirestoreService.shared.getUserProfileByEmail(email) {
            // Farklı UID ama aynı Email varsa: Mükerrer Hesap Uyarısı
            try? signOut()
            await MainActor.run {
                self.authError = "Bu e-posta adresiyle zaten bir hesabınız var. Lütfen uygulamaya ilk kayıt olduğunuz yöntemle (Apple veya Google) giriş yapın."
                self.isProfileLoading = false
                self.isProfileComplete = false
                self.currentUserProfile = nil
            }
        } else {
            await MainActor.run {
                self.isProfileComplete = false
                self.currentUserProfile = nil
                self.isProfileLoading = false
                self.authError = nil
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Native Google Sign In
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase ayarları bulunamadı."])
        }
        
        // Info.plist hatasını önlemek için ClientID'yi kod üzerinden enjekte ediyoruz
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Root ViewController'ı güvenli şekilde bulup Google Penceresini tetikle
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("Root View Controller bulunamadı.")
            return
        }

        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = gidSignInResult.user
        
        guard let idToken = user.idToken?.tokenString else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ID Token eksik"])
        }
        let accessToken = user.accessToken.tokenString

        // Firebase Google Kimliği Doğrulama Akışı
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        try await Auth.auth().signIn(with: credential)
    }
    
    // MARK: - Native Apple Sign In
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: fullName)
        let authResult = try await Auth.auth().signIn(with: credential)
        
        // Eğer kullanıcı ilk defa üye oluyorsa, Apple'dan gelen ad/soyad bilgilerini Firebase profiline patch'leyelim
        if let fullName = fullName, authResult.additionalUserInfo?.isNewUser == true {
            let changeRequest = authResult.user.createProfileChangeRequest()
            let name = [fullName.givenName, fullName.familyName].compactMap { $0 }.joined(separator: " ")
            changeRequest.displayName = name
            try? await changeRequest.commitChanges()
        }
    }
    
    // MARK: - Apple Sign In Helpers (Kriptografi & Nonce)
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Nonce oluşturulamadı. OSStatus \(errorCode)")
                }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
    
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Geçici Misafir Girişi
    func mockSignInAnonymously() async throws {
        let authResult = try await Auth.auth().signInAnonymously()
        self.user = authResult.user
    }
    
    // MARK: - Hesabı Tamamen Sil
    /// Kullanıcıya ait tüm verileri kalıcı olarak siler:
    /// - Sahibi olduğu cüzdanların tüm işlemleri ve kategorileri
    /// - Sahibi olduğu cüzdanlar
    /// - Üye olduğu cüzdanlardan üyelik kaydı
    /// - Firestore kullanıcı profili
    /// - Firebase Authentication hesabı
    func deleteAccount(wallets: [WalletModel]) async throws {
        guard let firebaseUser = user,
              let username = currentUserProfile?.username,
              let uid = currentUserProfile?.uid ?? user?.uid else {
            throw AccountDeletionError.userNotFound
        }
        
        let db = Firestore.firestore()
        
        // Adım 1: Cüzdanları işle
        for wallet in wallets {
            guard let walletId = wallet.id else { continue }
            
            if wallet.ownerId == username {
                // Sahibi olduğu cüzdanı tümüyle sil (alt koleksiyonlar dahil)
                try await deleteWalletCompletely(walletId: walletId, db: db)
            } else {
                // Üyesi olduğu cüzdanlardan kendini çıkar
                try await FirestoreService.shared.removeMember(walletId: walletId, userId: username)
            }
        }
        
        // Adım 2: Bildirimleri sil (kullanıcıya gönderilen veya kullanıcının gönderdiği)
        let notifSnapshot = try await db.collection("notifications")
            .whereField("recipientUsername", isEqualTo: username)
            .getDocuments()
        let notifBatch = db.batch()
        for doc in notifSnapshot.documents { notifBatch.deleteDocument(doc.reference) }
        try await notifBatch.commit()
        
        // Adım 3: Firestore kullanıcı profilini sil
        try await db.collection("users").document(uid).delete()
        
        // Adım 4: Firebase Auth hesabını sil
        // NOT: Bu işlem 'requiresRecentLogin' hatası verebilir.
        // Böyle bir durumda kullanıcıdan yeniden giriş yapması istenir.
        do {
            try await firebaseUser.delete()
            // Silme başarılı: GIDSignIn cache'ini temizle ve oturumu kapat.
            // Auth state listener zaten isAuthenticated = false yapacak,
            // bu çağrı Google cache'ini temizleyip geçişi hızlandırır.
            try? signOut()
        } catch let error as NSError {
            // AuthErrorCode.requiresRecentLogin = 17014
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw AccountDeletionError.requiresRecentLogin
            }
            throw error
        }
    }
    
    /// Bir cüzdanı tüm alt koleksiyonlarıyla birlikte Firestore'dan siler.
    private func deleteWalletCompletely(walletId: String, db: Firestore) async throws {
        // İşlemleri sil (batch, max 500 — büyük cüzdanlar için döngü)
        try await deleteBatchedSubcollection(walletId: walletId, subcollection: "transactions", db: db)
        
        // Kategorileri sil
        try await deleteBatchedSubcollection(walletId: walletId, subcollection: "categories", db: db)
        
        // Cüzdan dokümanını sil
        try await db.collection("wallets").document(walletId).delete()
    }
    
    private func deleteBatchedSubcollection(walletId: String, subcollection: String, db: Firestore) async throws {
        var hasMore = true
        while hasMore {
            let snapshot = try await db
                .collection("wallets").document(walletId)
                .collection(subcollection)
                .limit(to: 400) // Firestore batch limiti 500, güvenli pay bırakıyoruz
                .getDocuments()
            
            guard !snapshot.documents.isEmpty else { break }
            
            let batch = db.batch()
            for doc in snapshot.documents { batch.deleteDocument(doc.reference) }
            try await batch.commit()
            
            hasMore = snapshot.documents.count == 400
        }
    }
}

// MARK: - Hesap Silme Hata Tipleri
enum AccountDeletionError: LocalizedError {
    case userNotFound
    case requiresRecentLogin
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "Kullanıcı bilgileri bulunamadı."
        case .requiresRecentLogin:
            return "Güvenlik nedeniyle hesabınızı silmek için yeniden giriş yapmanız gerekiyor. Lütfen çıkış yapıp tekrar giriş yapın, ardından tekrar deneyin."
        }
    }
}

// MARK: - ImageCacheManager
import SwiftUI

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private init() {}
    
    // NSCache, bellekte (RAM) tutup hızlıca geri getirmeyi sağlar.
    private let cache = NSCache<NSString, UIImage>()
    
    /// Resmi hem belleğe hem diske kaydeder
    func saveImage(image: UIImage, for urlString: String) {
        // 1. Belleğe kaydet
        cache.setObject(image, forKey: urlString as NSString)
        
        // 2. Diske kaydet
        let path = getImagePath(for: urlString)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: path)
        }
    }
    
    /// Resmi bellekte arar, bulamazsa diskte arar
    func getImage(for urlString: String) -> UIImage? {
        // 1. Bellekte var mı?
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        // 2. Diskte var mı?
        let path = getImagePath(for: urlString)
        if let data = try? Data(contentsOf: path), let image = UIImage(data: data) {
            // Bir dahaki sefere daha hızlı gelmesi için belleğe de atalım
            cache.setObject(image, forKey: urlString as NSString)
            return image
        }
        
        // Hiçbir yerde yok
        return nil
    }
    
    /// URL üzerinden güvenli bir yerel dosya yolu (URL) oluşturur
    private func getImagePath(for urlString: String) -> URL {
        let folderName = "profile_images"
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let folderURL = cachesDirectory.appendingPathComponent(folderName)
        
        // Klasör yoksa oluştur
        if !fileManager.fileExists(atPath: folderURL.path) {
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        // URL karakterleri dosya sistemi için geçerli olmayabilir, o yüzden temiz ve eşsiz bir ad yapalım
        let rawBase64 = urlString.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        let safeImageName = rawBase64.components(separatedBy: .alphanumerics.inverted).joined()
        
        return folderURL.appendingPathComponent(safeImageName + ".jpg")
    }
    
    /// Tüm önbelleği temizler (Gerekirse ayarlar veya çıkış yaparken kullanılabilir)
    func clearCache() {
        cache.removeAllObjects()
        
        let folderName = "profile_images"
        let fileManager = FileManager.default
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        
        let folderURL = cachesDirectory.appendingPathComponent(folderName)
        try? fileManager.removeItem(at: folderURL)
    }
}
