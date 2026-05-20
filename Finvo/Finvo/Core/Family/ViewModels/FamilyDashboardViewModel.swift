import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

struct WholesomeSituation: Identifiable, Equatable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let targets: [String] // Kullanıcı isimleri
    let stats: [String: Double] // Kanıt olarak sunulacak harcama dağılımı
}

@MainActor
class FamilyDashboardViewModel: ObservableObject {
    @Published var wholesomeSituations: [WholesomeSituation] = []
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
    func fetchMemberProfiles(usernames: [String]) {
        guard !usernames.isEmpty else { return }
        Task {
            var fetched: [UserModel] = []
            for username in usernames {
                if let profile = try? await FirestoreService.shared.getUserProfileByUsername(username) {
                    fetched.append(profile)
                }
            }
            await MainActor.run {
                self.memberProfiles = fetched
            }
        }
    }

    // MARK: - Wholesome Debts (Aile İçi Durum Analizi)
    // Fix: nonisolated context'te @MainActor static property kullanılamaz,
    // bu yüzden default parametre değeri nil yapılıp metodun içinde fallback veriliyor.
    func calculateWholesomeDebts(from transactions: [TransactionModel], targetCurrency: CurrencyType? = nil) {
        let targetCurrency = targetCurrency ?? .tryCurrency
        let calendar = Calendar.current
        let now = Date()
        
        let thisMonthExpenses = transactions.filter { tx in
            calendar.isDate(tx.date, equalTo: now, toGranularity: .month) &&
            tx.type == .expense && 
            !tx.isDebt
        }
        
        guard !thisMonthExpenses.isEmpty else {
            self.wholesomeSituations = [
                WholesomeSituation(
                    title: "Mükemmel Denge".localized,
                    message: "Aile içi harcamalar şu an harika bir dengede! ⚖️ Mükemmel!".localized,
                    icon: "checkmark.seal.fill",
                    targets: [],
                    stats: [:]
                )
            ]
            return
        }

        var newSituations: [WholesomeSituation] = []

        // 1. Üye bazlı toplamları hesapla
        var userTotals: [String: Double] = [:]
        for tx in thisMonthExpenses {
            let converted = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: targetCurrency)
            userTotals[tx.createdBy, default: 0] += converted
        }

        let sortedTotals = userTotals.sorted { $0.value > $1.value }
        let totalSpend = userTotals.values.reduce(0, +)
        let memberCount = userTotals.count

        // 2. Çoklu Üye Analizi (3+ Üye Durumu)
        if memberCount >= 2 {
            let highest = sortedTotals.first!
            let lowest = sortedTotals.last!
            let threshold = ExchangeRateManager.shared.convert(amount: 300, from: .tryCurrency, to: targetCurrency)
            
            // DURUM A: Bir kişi aileyi sırtlıyor
            if highest.value > (totalSpend * 0.6) && memberCount >= 3 {
                let othersArr = sortedTotals.dropFirst().map { $0.key.capitalized }
                let others = othersArr.joined(separator: ", ")
                newSituations.append(WholesomeSituation(
                    title: "Finansal Lokomotif".localized,
                    message: "%@ bu ay aileyi sırtlamış gidiyor! 🚀 %@, biraz destek olma vakti.".localized(with: highest.key.capitalized, others),
                    icon: "tram.fill",
                    targets: [highest.key] + sortedTotals.dropFirst().map { $0.key },
                    stats: userTotals
                ))
            }
            // DURUM B: Genel uçurum (En çok ve en az arasında)
            else if highest.value - lowest.value > threshold {
                newSituations.append(WholesomeSituation(
                    title: "Harcama Lideri".localized,
                    message: "%@ bu ay liderliği kimseye bırakmamış! 🏆 %@ biraz geride kalmış.".localized(with: highest.key.capitalized, lowest.key.capitalized),
                    icon: "crown.fill",
                    targets: [highest.key, lowest.key],
                    stats: userTotals
                ))
            }
            
            // DURUM C: Çoklu üye - "Ekonomik" grup
            if memberCount >= 4 {
                let average = totalSpend / Double(memberCount)
                let lazyOnes = sortedTotals.filter { $0.value < average * 0.4 }.map { $0.key }
                if !lazyOnes.isEmpty && lazyOnes.count < memberCount {
                    newSituations.append(WholesomeSituation(
                        title: "Ekonomik Takım".localized,
                        message: "Bu grup ayı biraz fazla 'ekonomik' geçirmiş. 😅 Sıradaki harcamalar sizden mi?".localized,
                        icon: "leaf.fill",
                        targets: lazyOnes,
                        stats: userTotals
                    ))
                }
            }
        }

        // 3. Kategori Bazlı Analiz
        let groupedByCategory = Dictionary(grouping: thisMonthExpenses) { $0.resolvedMainCategoryName }
        for (catName, txs) in groupedByCategory {
            var catUserTotals: [String: Double] = [:]
            for tx in txs {
                let converted = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: targetCurrency)
                catUserTotals[tx.createdBy, default: 0] += converted
            }
            
            if catUserTotals.count >= 2 {
                let sortedCat = catUserTotals.sorted { $0.value > $1.value }
                let catHighest = sortedCat.first!
                let catLowest = sortedCat.last!
                let catThreshold = ExchangeRateManager.shared.convert(amount: 150, from: .tryCurrency, to: targetCurrency)
                
                if catHighest.value - catLowest.value > catThreshold {
                    newSituations.append(WholesomeSituation(
                        title: "%@ Ustası".localized(with: catName),
                        message: "%@ harcamalarında %@ bayrağı taşıyor! 🚩".localized(with: catName, catHighest.key.capitalized),
                        icon: txs.first?.categoryIcon ?? "cart.fill",
                        targets: [catHighest.key],
                        stats: catUserTotals
                    ))
                }
            }
        }

        // 4. Mükemmel Denge Durumu
        if newSituations.isEmpty {
            newSituations.append(WholesomeSituation(
                title: "Mükemmel Denge".localized,
                message: "Aile içi harcamalar şu an harika bir dengede! ⚖️ Mükemmel!".localized,
                icon: "checkmark.seal.fill",
                targets: [],
                stats: [:]
            ))
        }

        self.wholesomeSituations = Array(newSituations.shuffled().prefix(4))
    }
}
