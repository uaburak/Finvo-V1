import Foundation
import Combine
import SwiftUI

class WalletManager: ObservableObject {
    @Published var wallets: [WalletModel] = []
    @Published var activeWallet: WalletModel?
    
    init() {
        // UI Geliştirmesi için başlangıç verisi (Firestore'a bağlanana kadar)
        let defaultWallet = WalletModel(
            id: UUID().uuidString,
            name: "Ana Cüzdan",
            ownerId: "user_123",
            type: .personal,
            context: .general,
            members: ["user_123"],
            permissions: ["user_123": WalletRole.owner.rawValue]
        )
        
        self.wallets = [defaultWallet]
        self.activeWallet = defaultWallet
    }
    
    func createWallet(name: String, type: WalletType, context: WalletContext) {
        // Firestore bağlantısı yapılana kadar sadece lokale ekliyoruz
        let newWallet = WalletModel(
            id: UUID().uuidString,
            name: name,
            ownerId: "current_user_id",
            type: type,
            context: context,
            members: ["current_user_id"],
            permissions: ["current_user_id": WalletRole.owner.rawValue]
        )
        
        wallets.append(newWallet)
        
        // Yeni cüzdanı varsayılan olarak seç
        selectWallet(newWallet)
    }
    
    func selectWallet(_ wallet: WalletModel) {
        self.activeWallet = wallet
    }
    
    func updateWallet(_ updatedWallet: WalletModel) {
        if let index = wallets.firstIndex(where: { $0.id == updatedWallet.id }) {
            wallets[index] = updatedWallet
            // Eğer aktif cüzdan güncellendiyse aktif referansını da yenile
            if activeWallet?.id == updatedWallet.id {
                activeWallet = updatedWallet
            }
        }
    }
    
    func deleteWallet(id: String) {
        // Kullanıcının en az 1 cüzdanı olmalı
        guard wallets.count > 1 else { return }
        
        wallets.removeAll(where: { $0.id == id })
        
        // Silinen cüzdan aktif cüzdansa, ilk cüzdanı seç
        if activeWallet?.id == id {
            activeWallet = wallets.first
        }
    }
    
    // YENİ UYE YÖNETİMİ MOCK
    func addMember(to walletId: String, memberId: String, role: WalletRole) {
        if let index = wallets.firstIndex(where: { $0.id == walletId }) {
            var updatedWallet = wallets[index]
            if !updatedWallet.members.contains(memberId) {
                updatedWallet.members.append(memberId)
            }
            updatedWallet.permissions[memberId] = role.rawValue
            updateWallet(updatedWallet)
        }
    }
    
    func removeMember(from walletId: String, memberId: String) {
        if let index = wallets.firstIndex(where: { $0.id == walletId }) {
            var updatedWallet = wallets[index]
            updatedWallet.members.removeAll(where: { $0 == memberId })
            updatedWallet.permissions.removeValue(forKey: memberId)
            updateWallet(updatedWallet)
        }
    }
}
