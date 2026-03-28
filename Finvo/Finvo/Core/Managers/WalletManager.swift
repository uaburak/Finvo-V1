import Foundation
import Combine
import FirebaseAuth

@MainActor
class WalletManager: ObservableObject {
    @Published var wallets: [WalletModel] = []
    @Published var activeWallet: WalletModel?

    /// Son seçilen cüzdan ID'sini cihazda kalıcı olarak saklar
    private var lastActiveWalletId: String {
        get { UserDefaults.standard.string(forKey: "lastActiveWalletId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastActiveWalletId") }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Dinamik cüzdan verilerini FirestoreService üzerinden takip et
        FirestoreService.shared.$wallets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newWallets in
                guard let self else { return }
                self.wallets = newWallets
                
                if let currentActive = self.activeWallet {
                    if let updated = newWallets.first(where: { $0.id == currentActive.id }) {
                        // Aktif cüzdan hâlâ varsa güncelle
                        self.activeWallet = updated
                    } else {
                        // Aktif cüzdan artık listede yok (silinmiş veya yetki alınmış) -> İlk cüzdana geç
                        self.activeWallet = newWallets.first
                        if let first = newWallets.first {
                            self.lastActiveWalletId = first.id ?? ""
                        }
                    }
                } else if !newWallets.isEmpty {
                    // İlk açılış veya seçim yokken cüzdanlar geldi: kaydedilmiş ID'yi kontrol et
                    if !self.lastActiveWalletId.isEmpty,
                       let saved = newWallets.first(where: { $0.id == self.lastActiveWalletId }) {
                        self.activeWallet = saved
                    } else {
                        self.activeWallet = newWallets.first
                    }
                } else {
                    self.activeWallet = nil
                }
            }
            .store(in: &cancellables)
        
        // Profil yüklendiğinde ve username oluştuğunda dinleyiciyi başlat
        AuthenticationManager.shared.$currentUserProfile
            .receive(on: DispatchQueue.main)
            .sink { profile in
                if let username = profile?.username, !username.isEmpty {
                    FirestoreService.shared.startListeningWallets(forUser: username)
                } else {
                    FirestoreService.shared.stopListeningWallets()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Aktif Cüzdan Seçimi
    func selectWallet(_ wallet: WalletModel) {
        self.activeWallet = wallet
        self.lastActiveWalletId = wallet.id ?? ""
    }
    
    // MARK: - Firestore Proxy API
    func createWallet(name: String, type: WalletType, context: WalletContext) {
        let username = AuthenticationManager.shared.currentUserProfile?.username ?? "unknown_user"
        let newWallet = WalletModel(
            name: name,
            ownerId: username,
            type: type,
            context: context,
            members: [username],
            permissions: [username: WalletRole.owner.rawValue]
        )
        
        Task {
            try? await FirestoreService.shared.createWallet(newWallet)
        }
    }
    
    func updateWallet(_ updatedWallet: WalletModel) {
        Task {
            try? await FirestoreService.shared.updateWallet(updatedWallet)
        }
    }
    
    func deleteWallet(id: String) {
        guard wallets.count > 1 else { return } // Son kalan zorunlu silinmez (Opsiyonel Güvenlik)
        Task {
            try? await FirestoreService.shared.deleteWallet(id: id)
        }
    }
    
    func addMember(to walletId: String, memberId: String, role: WalletRole) {
        Task {
            try? await FirestoreService.shared.addMember(walletId: walletId, userId: memberId, role: role)
        }
    }
    
    func removeMember(from walletId: String, memberId: String) {
        Task {
            try? await FirestoreService.shared.removeMember(walletId: walletId, userId: memberId)
        }
    }
}
