import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import GoogleSignIn
import Combine
import CryptoKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated: Bool = false
    @Published var isProfileComplete: Bool = false
    @Published var currentUserProfile: User?
    var pendingExternalName: String? // For Apple Sign In
    
    private let db = Firestore.firestore()
    
    static let shared = AuthenticationManager()
    
    private init() {
        self.user = Auth.auth().currentUser
        self.isAuthenticated = self.user != nil
        
        // Kimlik durumu değişikliklerini dinle
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = user != nil
            if user != nil {
                Task {
                    await self.fetchUserProfile()
                }
            } else {
                self.isProfileComplete = false
                self.currentUserProfile = nil
            }
        }
    }
    
    // Kullanıcının Firestore'da profil kaydı olup olmadığını kontrol eder ve çeker
    func fetchUserProfile() async {
        guard let uid = user?.uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if doc.exists {
                self.currentUserProfile = try? doc.data(as: User.self)
                self.isProfileComplete = true
            } else {
                self.isProfileComplete = false
                self.currentUserProfile = nil
            }
        } catch {
            print("Kullanıcı profili çekilirken hata oluştu: \(error)")
        }
    }
    
    // Google ile Giriş Yap
    func signInWithGoogle() async throws {
        // 1. Root View Controller'ı bul (Google ekranını üzerinde açmak için)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("Root View Controller bulunamadı.")
            return
        }

        // 2. Google SDK üzerinden giriş akışını başlat
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = gidSignInResult.user
        
        guard let idToken = user.idToken?.tokenString else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ID Token eksik"])
        }
        let accessToken = user.accessToken.tokenString

        // 3. Firebase kimlik bilgisi oluştur
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        // 4. Firebase'e giriş yap
        try await Auth.auth().signIn(with: credential)
    }
    
    // Apple ile Giriş Yap (Token ve Nonce ile)
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws {
        // Firebase için Apple credential oluştur (Apple'a özel metod)
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: fullName)
        try await Auth.auth().signIn(with: credential)
        await fetchUserProfile()
    }
    
    // Kullanıcı Profilini Güncelle (İsim vb için)
    func updateUserProfile(name: String) async {
        guard let user = user else { return }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        do {
            try await changeRequest.commitChanges()
            // Firestore tarafını da güncellemek isterseniz:
             if let uid = self.user?.uid {
                 try? await db.collection("users").document(uid).setData(["displayName": name], merge: true)
             }
        } catch {
            print("Profil güncelleme hatası: \(error)")
        }
    }
    
    // MARK: - Apple Sign In Helpers
    
    // Rastgele bir nonce string oluşturur
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // String'in SHA256 özetini (digest) alır
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Çıkış Yap
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // Hesabı Sil
    func deleteAccount() async throws {
        guard let user = user else { return }
        try await user.delete()
    }
    
    // Test: Update Pro Status
    func updateProStatus(isPro: Bool) async {
        guard let uid = user?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData(["isPro": isPro])
            // Update local
            if var profile = currentUserProfile {
                profile.isPro = isPro
                self.currentUserProfile = profile
            }
        } catch {
            print("Pro status update failed: \(error)")
        }
    }
}
