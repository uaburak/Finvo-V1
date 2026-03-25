import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class TransactionManager: ObservableObject {
    @Published var transactions: [TransactionModel] = []
    @Published var hasLoaded = false
    
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    var totalIncome: Double {
        transactions.filter { $0.type == .income && !$0.isDebt }.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        transactions.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { $0 + $1.amount }
    }
    
    private var currentWalletId: String?
    
    // Geçerli cüzdanın ID'si ile işlemleri dinlemeye başla
    func startListening(walletId: String) {
        // Aynı cüzdan için zaten dinliyorsak tekrar başlatma
        guard walletId != currentWalletId else { return }
        stopListening()
        currentWalletId = walletId
        
        listener = db.collection("wallets").document(walletId).collection("transactions")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching transactions: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.transactions = []
                    return
                }
                
                self.transactions = documents.compactMap { try? $0.data(as: TransactionModel.self) }
                self.hasLoaded = true
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        currentWalletId = nil
        hasLoaded = false
    }
    
    // Borç ödeme operasyonu
    func payDebtInstallment(for debtTransaction: TransactionModel, currentUsername: String) async throws {
        guard debtTransaction.isDebt, let total = debtTransaction.totalInstallments, let paid = debtTransaction.paidInstallments, paid < total else {
            throw NSError(domain: "TransactionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geçersiz borç işlemi veya borç zaten kapalı."])
        }
        
        let installmentAmount = debtTransaction.amount / Double(total)
        
        // 1. Yeni bir "Gider" işlemi yarat (Veresiye/Borç Ödemesi olarak)
        let newExpense = TransactionModel(
            walletId: debtTransaction.walletId,
            type: .expense,
            amount: installmentAmount,
            mainCategoryName: "Finansal Giderler",
            subCategoryName: "Borç Ödemesi",
            categoryIcon: "arrow.right.arrow.left.circle.fill",
            categoryColor: "red",
            date: Date(),
            note: "\(debtTransaction.debtContact ?? "Bilinmeyen Kişi") için \(paid + 1). Taksit Ödemesi",
            createdBy: currentUsername,
            createdAt: Date(),
            isDebt: false
        )
        
        // 2. Kök borç işleminin taksitini +1 artır ve isPaid kontrolü yap
        var updatedDebt = debtTransaction
        updatedDebt.paidInstallments = paid + 1
        if updatedDebt.paidInstallments == total {
            updatedDebt.isPaid = true
        }
        
        // 3. İki işlemi de Firestore'a yaz
        let debtToSave = updatedDebt
        async let step1: Void = FirestoreService.shared.createTransaction(newExpense)
        async let step2: Void = FirestoreService.shared.updateTransaction(debtToSave)
        
        _ = try await (step1, step2)
    }
}
