import Foundation
import Combine
import SwiftUI

@MainActor
class FamilyDashboardViewModel: ObservableObject {
    @Published var wholesomeMessages: [String] = []
    
    @Published var pendingMissionsCount: Int = 0 // Mock for V1
    @Published var pendingShoppingItemsCount: Int = 0 // Mock for V1
    
    @Published var memberProfiles: [UserModel] = []
    
    func fetchMemberProfiles(uids: [String]) {
        guard !uids.isEmpty else { return }
        Task {
            var fetched: [UserModel] = []
            for uid in uids {
                if let profile = try? await FirestoreService.shared.getUserProfile(uid: uid) {
                    fetched.append(profile)
                }
            }
            await MainActor.run {
                self.memberProfiles = fetched
            }
        }
    }
    
    // Temel kategoriler için emoji haritası (Eğlenceli mesajlar için)
    let categoryEmojis: [String: String] = [
        "Kafe": "☕️",
        "Kahve": "☕️",
        "Yemek": "🍔",
        "Restoran": "🍕",
        "Market": "🛒",
        "Eğlence": "🍿",
        "Sinema": "🎬",
        "Tatlı": "🍦"
    ]
    
    let actionWords: [String: String] = [
        "Kafe": "kahve ısmarlama",
        "Kahve": "kahve ısmarlama",
        "Yemek": "yemek ısmarlama",
        "Restoran": "yemek ısmarlama",
        "Market": "market alışverişi yapma",
        "Eğlence": "bilet alma",
        "Sinema": "mısır ısmarlama",
        "Tatlı": "tatlı ısmarlama"
    ]
    
    func calculateWholesomeDebts(from transactions: [TransactionModel]) {
        // Sadece eğlenceli/tatlı kategorilerde harcama farklarını hesapla
        let whitelistedCategories = Set(categoryEmojis.keys)
        
        let expenses = transactions.filter { tx in
            tx.type == .expense && 
            !tx.isDebt && 
            whitelistedCategories.contains(tx.mainCategoryName)
        }
        
        var categoryUserSpends: [String: [String: Double]] = [:] // [Kategori: [Kullanıcı: Tutar]]
        
        for tx in expenses {
            let cat = tx.mainCategoryName
            let user = tx.createdBy
            
            if categoryUserSpends[cat] == nil {
                categoryUserSpends[cat] = [:]
            }
            let currentAmount = categoryUserSpends[cat]![user] ?? 0.0
            categoryUserSpends[cat]![user] = currentAmount + tx.amount
        }
        
        var newMessages: [String] = []
        
        for (category, userSpends) in categoryUserSpends {
            guard userSpends.keys.count >= 2 else { continue } // En az iki kişinin o kategoride kaydı olmalı
            
            let sortedUsers = userSpends.sorted { $0.value > $1.value }
            let highestSpender = sortedUsers.first!
            let lowestSpender = sortedUsers.last!
            
            let diff = highestSpender.value - lowestSpender.value
            if diff > 150 { // 150₺'den fazla harcama farkı varsa tatlı bir borç çıkar
                let emoji = categoryEmojis[category] ?? "🎁"
                let action = actionWords[category] ?? "\(category.lowercased()) borcu"
                
                // İsimleri baş harfi büyük yapalım
                let payer = lowestSpender.key.capitalized
                let payee = highestSpender.key.capitalized
                
                let rnd = Int.random(in: 0...2)
                var msg = ""
                if action.contains("borcu") {
                     msg = "\(payer)'nin \(payee)'a \(action) var! \(emoji)"
                } else {
                    if rnd == 0 {
                        msg = "\(payer)'nin \(payee)'a \(action) vakti geldi! \(emoji)"
                    } else if rnd == 1 {
                        msg = "Bu sefer \(action) sırası sende \(payer)! \(emoji) "
                    } else {
                        msg = "\(payer)'nin \(payee)'a \(action) var! \(emoji)"
                    }
                }
                newMessages.append(msg)
            }
        }
        
        if newMessages.isEmpty {
            self.wholesomeMessages = ["Aile içi harcamalar şu an harika bir dengede! ⚖️ Mükemmel!"]
        } else {
            // Karıştırıp sadece en önemli 2 tanesini gösterelim
            self.wholesomeMessages = Array(newMessages.shuffled().prefix(2))
        }
    }
}
