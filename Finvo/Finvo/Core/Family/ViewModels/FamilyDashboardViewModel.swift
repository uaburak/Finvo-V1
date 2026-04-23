import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class FamilyDashboardViewModel: ObservableObject {
    @Published var wholesomeMessages: [String] = []
    @Published var pendingMissionsCount: Int = 0
    @Published var pendingShoppingItemsCount: Int = 0
    @Published var memberProfiles: [UserModel] = []

    private let db = Firestore.firestore()
    private var shoppingListener: ListenerRegistration?
    private var missionsListener: ListenerRegistration?
    private var currentWalletId: String?

    // MARK: - Live Count Listeners
    func startCountListeners(walletId: String) {
        guard walletId != currentWalletId else { return }
        currentWalletId = walletId

        shoppingListener?.remove()
        missionsListener?.remove()

        shoppingListener = db.collection("wallets")
            .document(walletId)
            .collection("shoppingList")
            .whereField("isPurchased", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.pendingShoppingItemsCount = snapshot?.documents.count ?? 0
            }

        missionsListener = db.collection("wallets")
            .document(walletId)
            .collection("missions")
            .whereField("isApproved", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.pendingMissionsCount = snapshot?.documents.count ?? 0
            }
    }

    func stopListeners() {
        shoppingListener?.remove()
        missionsListener?.remove()
        shoppingListener = nil
        missionsListener = nil
        currentWalletId = nil
    }

    // MARK: - Member Profiles
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

    // MARK: - Wholesome Debts
    let categoryEmojis: [String: String] = [
        "Kafe": "☕️", "Kahve": "☕️", "Yemek": "🍔",
        "Restoran": "🍕", "Market": "🛒", "Eğlence": "🍿",
        "Sinema": "🎬", "Tatlı": "🍦"
    ]

    let actionWords: [String: String] = [
        "Kafe": "kahve ısmarlama", "Kahve": "kahve ısmarlama",
        "Yemek": "yemek ısmarlama", "Restoran": "yemek ısmarlama",
        "Market": "market alışverişi yapma", "Eğlence": "bilet alma",
        "Sinema": "mısır ısmarlama", "Tatlı": "tatlı ısmarlama"
    ]

    func calculateWholesomeDebts(from transactions: [TransactionModel]) {
        let whitelistedCategories = Set(categoryEmojis.keys)

        let expenses = transactions.filter { tx in
            tx.type == .expense && !tx.isDebt && whitelistedCategories.contains(tx.mainCategoryName)
        }

        var categoryUserSpends: [String: [String: Double]] = [:]
        for tx in expenses {
            let cat = tx.mainCategoryName
            let user = tx.createdBy
            if categoryUserSpends[cat] == nil { categoryUserSpends[cat] = [:] }
            categoryUserSpends[cat]![user, default: 0] += tx.amount
        }

        var newMessages: [String] = []
        for (category, userSpends) in categoryUserSpends {
            guard userSpends.keys.count >= 2 else { continue }
            let sortedUsers = userSpends.sorted { $0.value > $1.value }
            let highestSpender = sortedUsers.first!
            let lowestSpender = sortedUsers.last!
            let diff = highestSpender.value - lowestSpender.value

            if diff > 150 {
                let emoji = categoryEmojis[category] ?? "🎁"
                let action = actionWords[category] ?? "\(category.lowercased()) borcu"
                let payer = lowestSpender.key.capitalized
                let payee = highestSpender.key.capitalized
                let rnd = Int.random(in: 0...2)
                var msg = ""
                if action.contains("borcu") {
                    msg = "\(payer)'nin \(payee)'a \(action) var! \(emoji)"
                } else if rnd == 0 {
                    msg = "\(payer)'nin \(payee)'a \(action) vakti geldi! \(emoji)"
                } else if rnd == 1 {
                    msg = "Bu sefer \(action) sırası sende \(payer)! \(emoji)"
                } else {
                    msg = "\(payer)'nin \(payee)'a \(action) var! \(emoji)"
                }
                newMessages.append(msg)
            }
        }

        self.wholesomeMessages = newMessages.isEmpty
            ? ["Aile içi harcamalar şu an harika bir dengede! ⚖️ Mükemmel!"]
            : Array(newMessages.shuffled().prefix(2))
    }
}
